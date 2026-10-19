import 'dart:typed_data';

import 'package:minecraft_content_service/minecraft_content_service.dart';
import 'package:test/test.dart';

MtnMinecraftContentMod project(String id) => MtnMinecraftContentMod(
  key: id, name: id, providers: <MtnMinecraftContentProviderMetadata>[
    MtnMinecraftContentProviderMetadata(provider: 'modrinth', id: id),
  ],
);

MtnMinecraftContentVersion release(
  MtnMinecraftContent content,
  String id, {
  String minecraft = '1.21.11',
  MtnMinecraftModLoaderType loader = MtnMinecraftModLoaderType.fabric,
  DateTime? published,
  List<MtnMinecraftContentDependency> dependencies = const <MtnMinecraftContentDependency>[],
}) => MtnMinecraftContentVersion(
  key: id, content: content, name: id, version: id,
  releaseType: MtnMinecraftContentVersionReleaseType.release,
  modLoaders: <MtnMinecraftModLoaderType>[loader],
  gameVersions: <String>[minecraft],
  providers: <MtnMinecraftContentProviderMetadata>[MtnMinecraftContentProviderMetadata(provider: 'modrinth', id: id)],
  publishedAt: published,
  dependencies: dependencies,
);

MtnMinecraftContentPackage pack({
  MtnMinecraftContentPackageMutationPolicy policy = MtnMinecraftContentPackageMutationPolicy.appendOnly,
  List<MtnMinecraftContentPackageItem> items = const <MtnMinecraftContentPackageItem>[],
  MtnMinecraftContentPackageLock? lock,
}) => MtnMinecraftContentPackage(
  id: 'my-package', title: 'Test Package',
  minecraftVersion: '1.21.11', modLoader: MtnMinecraftModLoaderType.fabric,
  loaderVersion: '0.16.14', ramMiB: 4096, ownerName: 'Test owner',
  createdAt: DateTime.utc(2026, 10, 13), updatedAt: DateTime.utc(2026, 10, 14),
  mutationPolicy: policy, items: items, lock: lock,
);

class VersionService extends MtnMinecraftContentService {
  VersionService(this.content, this.current, this.available);
  final MtnMinecraftContent content;
  final MtnMinecraftContentVersion current;
  final List<MtnMinecraftContentVersion> available;

  @override
  Future<MtnMinecraftContent> getContent(String providerName, String id) async => content;

  @override
  Future<MtnMinecraftContentVersion> getVersion(String providerName, String id) async => current;

  @override
  Future<MtnMinecraftContentVersionListResult> getVersions(String providerName, MtnMinecraftContent content, MtnMinecraftContentVersionListRequest request) async =>
      MtnMinecraftContentVersionListResult(versions: available, offset: 0, limit: 50, hasMore: false);
}

void main() {
  test('chosen provider version is typed, compatible, local and saved in encrypted record', () async {
    final package = pack();
    final fabric = project('fabric-api');
    final selected = release(fabric, 'fabric-0.130.0');
    expect(package.add(selected), isTrue);
    expect(package.add(selected), isFalse);
    final item = package.getItem('modrinth:fabric-api')!;
    expect(identical(item.package, package), isTrue);
    expect(item.type, MtnMinecraftContentType.mod);
    expect(item.source, MtnMinecraftContentPackageSource.local);
    expect(item.selectedVersionId, 'fabric-0.130.0');
    expect(item.version, same(selected));
    expect(item.effectiveEnabled, isTrue);
    expect(item.toMap().containsKey('selectedVersionId'), isFalse);
    expect(() => package.encode(), throwsStateError);

    final record = MtnMinecraftContentPackageRecord(package: package, source: MtnMinecraftContentPackageSource.downloaded);
    final codec = MtnMinecraftContentPackageRecordCodec();
    final secret = Uint8List.fromList(List<int>.generate(32, (index) => index));
    final bytes = await codec.encrypt(record, key: secret, keyId: 'demo-key');
    final restored = await codec.decrypt(bytes, key: secret);
    final item2 = restored.package.getItem('modrinth:fabric-api')!;
    expect(item2.selectedVersionId, 'fabric-0.130.0');
    expect(item2.version, isNull);
    expect(item2.source, MtnMinecraftContentPackageSource.local);
    expect(restored.source, MtnMinecraftContentPackageSource.downloaded);
    expect(identical(item2.package, restored.package), isTrue);
    await restored.package.hydrateSequential(VersionService(fabric, selected, <MtnMinecraftContentVersion>[]));
    expect(item2.version?.version, 'fabric-0.130.0');
  });

  test('an item reused in another package is copied without stealing its original owner', () {
    final item = MtnMinecraftContentPackageItem(
      provider: 'modrinth', projectId: 'reused', title: 'Reused Mod',
      type: MtnMinecraftContentType.mod, direct: true,
      source: MtnMinecraftContentPackageSource.downloaded,
      permissions: MtnMinecraftContentItemPermission.values,
    );
    final first = pack(items: <MtnMinecraftContentPackageItem>[item]);
    final second = pack(items: <MtnMinecraftContentPackageItem>[...first.items]);
    final firstItem = first.items.single;
    final secondItem = second.items.single;
    expect(identical(firstItem, item), isTrue);
    expect(identical(secondItem, firstItem), isFalse);
    expect(identical(firstItem.package, first), isTrue);
    expect(identical(secondItem.package, second), isTrue);
    expect(secondItem.source, MtnMinecraftContentPackageSource.downloaded);
    firstItem.enabled = false;
    expect(firstItem.effectiveEnabled, isFalse);
    expect(secondItem.effectiveEnabled, isTrue);
    expect(MtnMinecraftContentPackage.fromLocalMap(second.toLocalMap()).items.single.source, MtnMinecraftContentPackageSource.downloaded);
  });

  test('auto-update defaults on and explicit opt-out survives encrypted local records', () async {
    final item = MtnMinecraftContentPackageItem(
      provider: 'modrinth', projectId: 'optional', title: 'Optional Mod',
      type: MtnMinecraftContentType.mod, direct: true, selectedVersionId: 'v1',
      permissions: const <MtnMinecraftContentItemPermission>[MtnMinecraftContentItemPermission.update],
    );
    final package = pack(policy: MtnMinecraftContentPackageMutationPolicy.none,
      items: <MtnMinecraftContentPackageItem>[item]);
    expect(item.autoUpdate, isTrue);
    expect(package.canSetAutoUpdate(item), isTrue);
    expect(item.toLocalMap().containsKey('autoUpdate'), isFalse);
    expect(MtnMinecraftContentPackageItem.fromLocalMap(item.toLocalMap()).autoUpdate, isTrue);

    item.autoUpdate = false;
    expect(item.autoUpdate, isFalse);
    expect(package.hasUpdateEligibleItems, isFalse);
    expect(package.needsUpdateCheck(), isFalse);
    expect(item.selectedVersionId, 'v1');
    expect(item.toLocalMap()['autoUpdate'], isFalse);
    expect(item.toMap().containsKey('autoUpdate'), isFalse);
    expect(() => MtnMinecraftContentPackageItem.fromMap(item.toLocalMap()), throwsFormatException);
    final invalid = Map<String, dynamic>.from(item.toLocalMap())..['autoUpdate'] = 'no';
    expect(() => MtnMinecraftContentPackageItem.fromLocalMap(invalid), throwsFormatException);

    final record = MtnMinecraftContentPackageRecord(
      package: package, source: MtnMinecraftContentPackageSource.local);
    final codec = MtnMinecraftContentPackageRecordCodec();
    final key = Uint8List.fromList(List<int>.generate(32, (index) => index));
    final bytes = await codec.encrypt(record, key: key, keyId: 'auto-update-test');
    final restored = (await codec.decrypt(bytes, key: key)).package;
    final reloaded = restored.getItem(item.key)!;
    expect(reloaded.autoUpdate, isFalse);
    expect(restored.hasUpdateEligibleItems, isFalse);
    expect(restored.canSetAutoUpdate(reloaded), isTrue);

    reloaded.autoUpdate = true;
    expect(reloaded.autoUpdate, isTrue);
    expect(restored.hasUpdateEligibleItems, isTrue);
    expect(restored.needsUpdateCheck(), isTrue);
  });

  test('auto-update switch respects readOnly, protected appendOnly and direct permissions', () {
    MtnMinecraftContentPackageItem makeItem(String project, {MtnMinecraftContentPackageSource source = MtnMinecraftContentPackageSource.local,
      bool direct = true, bool autoUpdate = true, Iterable<MtnMinecraftContentItemPermission> permissions = const <MtnMinecraftContentItemPermission>[MtnMinecraftContentItemPermission.update]}) =>
        MtnMinecraftContentPackageItem(
          provider: 'modrinth', projectId: project, title: project,
          type: MtnMinecraftContentType.mod, direct: direct,
          source: source, autoUpdate: autoUpdate, permissions: permissions,
        );

    final readonlyItem = makeItem('readonly');
    final readonly = pack(policy: MtnMinecraftContentPackageMutationPolicy.readOnly,
      items: <MtnMinecraftContentPackageItem>[readonlyItem]);
    expect(readonly.canSetAutoUpdate(readonlyItem), isFalse);
    readonlyItem.autoUpdate = false;
    expect(readonlyItem.autoUpdate, isTrue);

    final protectedItem = makeItem('protected', source: MtnMinecraftContentPackageSource.downloaded);
    final localItem = makeItem('added');
    final appendOnly = pack(policy: MtnMinecraftContentPackageMutationPolicy.appendOnly,
      items: <MtnMinecraftContentPackageItem>[protectedItem, localItem]);
    MtnMinecraftContentPackageRecord(package: appendOnly, source: MtnMinecraftContentPackageSource.downloaded);
    expect(appendOnly.canSetAutoUpdate(protectedItem), isFalse);
    protectedItem.autoUpdate = false;
    expect(protectedItem.autoUpdate, isTrue);
    expect(appendOnly.canSetAutoUpdate(localItem), isTrue);
    localItem.autoUpdate = false;
    expect(localItem.autoUpdate, isFalse);

    final dependency = makeItem('dependency', direct: false);
    final noPermission = makeItem('no-permission', permissions: const <MtnMinecraftContentItemPermission>[]);
    final editable = pack(policy: MtnMinecraftContentPackageMutationPolicy.none,
      items: <MtnMinecraftContentPackageItem>[dependency, noPermission]);
    expect(editable.canSetAutoUpdate(dependency), isFalse);
    dependency.autoUpdate = false;
    expect(dependency.autoUpdate, isTrue);
    expect(editable.canSetAutoUpdate(noPermission), isFalse);
    noPermission.autoUpdate = false;
    expect(noPermission.autoUpdate, isTrue);
  });

  test('type and loader compatibility comes from the selected provider version', () {
    final package = pack();
    final fabric = project('fabric-api');
    expect(package.add(release(fabric, 'wrong-minecraft', minecraft: '1.20.1')), isFalse);
    expect(package.add(release(fabric, 'wrong-loader', loader: MtnMinecraftModLoaderType.forge)), isFalse);
    expect(package.items, isEmpty);

    final resources = MtnMinecraftContentResourcePack(
      key: 'textures', name: 'Textures',
      providers: <MtnMinecraftContentProviderMetadata>[MtnMinecraftContentProviderMetadata(provider: 'modrinth', id: 'textures')],
    );
    expect(package.add(release(resources, 'texture-version', loader: MtnMinecraftModLoaderType.vanilla)), isTrue);
    expect(package.items.single.type, MtnMinecraftContentType.resourcePack);
  });

  test('enabled setter silently honors readOnly, downloaded appendOnly and local changes', () {
    final original = MtnMinecraftContentPackageItem(
      provider: 'modrinth', projectId: 'original', title: 'Original',
      type: MtnMinecraftContentType.mod, direct: true,
      source: MtnMinecraftContentPackageSource.downloaded,
      permissions: MtnMinecraftContentItemPermission.values,
    );
    final downloaded = pack(items: <MtnMinecraftContentPackageItem>[original]);
    MtnMinecraftContentPackageRecord(package: downloaded, source: MtnMinecraftContentPackageSource.downloaded);
    original.enabled = false;
    expect(original.enabled, isTrue);

    final added = release(project('addon'), 'addon-1');
    expect(downloaded.add(added), isTrue);
    final local = downloaded.getItem('modrinth:addon')!;
    local.enabled = false;
    expect(local.enabled, isFalse);
    expect(local.effectiveEnabled, isFalse);
    local.enabled = true;
    expect(local.effectiveEnabled, isTrue);
    expect(downloaded.remove(local), isTrue);
    expect(downloaded.getItem(local.key), isNull);

    final readonly = pack(policy: MtnMinecraftContentPackageMutationPolicy.readOnly, items: <MtnMinecraftContentPackageItem>[
      MtnMinecraftContentPackageItem(
        provider: 'modrinth', projectId: 'locked', title: 'Locked', type: MtnMinecraftContentType.mod,
        direct: true, permissions: MtnMinecraftContentItemPermission.values,
      ),
    ]);
    readonly.items.single.enabled = false;
    expect(readonly.items.single.enabled, isTrue);
    expect(readonly.add(added), isFalse);
    expect(readonly.remove(readonly.items.single), isFalse);
  });

  test('shared dependencies remain active while any direct parent is enabled after lock invalidation', () {
    final rootA = MtnMinecraftContentPackageItem(
      provider: 'modrinth', projectId: 'a', type: MtnMinecraftContentType.mod, title: 'A', direct: true,
      permissions: MtnMinecraftContentItemPermission.values,
    );
    final rootB = MtnMinecraftContentPackageItem(
      provider: 'modrinth', projectId: 'b', type: MtnMinecraftContentType.mod, title: 'B', direct: true,
      permissions: MtnMinecraftContentItemPermission.values,
    );
    final dep = MtnMinecraftContentPackageItem(provider: 'modrinth', projectId: 'dep', type: MtnMinecraftContentType.mod, title: 'Dep');
    final lock = MtnMinecraftContentPackageLock(
      versions: <MtnMinecraftContentPackageLockedVersion>[
        for (final id in <String>['a', 'b', 'dep'])
          MtnMinecraftContentPackageLockedVersion(itemKey: 'modrinth:$id', versionId: '$id-v1', fileName: '$id.jar', fileId: '$id-file'),
      ],
      edges: <MtnMinecraftContentPackageLockedEdge>[
        MtnMinecraftContentPackageLockedEdge(sourceKey: 'modrinth:a', targetKey: 'modrinth:dep', type: MtnMinecraftContentDependencyType.required),
        MtnMinecraftContentPackageLockedEdge(sourceKey: 'modrinth:b', targetKey: 'modrinth:dep', type: MtnMinecraftContentDependencyType.required),
      ],
    );
    final package = pack(policy: MtnMinecraftContentPackageMutationPolicy.none,
        items: <MtnMinecraftContentPackageItem>[rootA, rootB, dep], lock: lock);
    expect(dep.effectiveEnabled, isTrue);
    rootA.enabled = false;
    expect(dep.effectiveEnabled, isTrue);
    rootB.enabled = false;
    expect(dep.effectiveEnabled, isFalse);

    expect(package.add(release(project('addon'), 'addon-1')), isTrue);
    expect(package.lock, isNull);
    expect(package.dependencyEdges.length, 2);
    final reopened = MtnMinecraftContentPackage.fromLocalMap(package.toLocalMap());
    expect(reopened.dependencyEdges.length, 2);
    expect(reopened.getItem('modrinth:a')!.selectedVersionId, 'a-v1');
    expect(reopened.getItem('modrinth:dep')!.selectedVersionId, 'dep-v1');
    expect(reopened.getItem('modrinth:dep')!.effectiveEnabled, isFalse);
    expect(() => package.toMap(), throwsStateError);
  });

  test('provider update candidates live on package, not serialized item, and canUpdate follows map', () async {
    final content = project('fabric-api');
    final old = release(content, 'v1', published: DateTime.utc(2026, 9, 1));
    final latest = release(content, 'v2', published: DateTime.utc(2026, 10, 1));
    final package = pack(policy: MtnMinecraftContentPackageMutationPolicy.none);
    expect(package.add(old), isTrue);
    final item = package.items.single;
    expect(item.canUpdate, isFalse);
    await package.checkUpdates(service: VersionService(content, old, <MtnMinecraftContentVersion>[old, latest]));
    expect(item.canUpdate, isTrue);
    expect(package.updateList[item], same(latest));
    expect(item.toLocalMap().containsKey('updateVersion'), isFalse);
    expect(package.toLocalMap().containsKey('updateList'), isFalse);
    expect(package.remove(item), isTrue);
    expect(package.updateList, isEmpty);
  });
  test('local dependency promotion and demotion preserves one item and valid serialization', () {
    final root = MtnMinecraftContentPackageItem(
      provider: 'modrinth', projectId: 'root', title: 'Root', type: MtnMinecraftContentType.mod,
      direct: true, permissions: MtnMinecraftContentItemPermission.values,
    );
    final dep = MtnMinecraftContentPackageItem(
      provider: 'modrinth', projectId: 'shared', title: 'Shared', type: MtnMinecraftContentType.mod,
      direct: false,
    );
    final locked = MtnMinecraftContentPackageLock(
      versions: <MtnMinecraftContentPackageLockedVersion>[
        MtnMinecraftContentPackageLockedVersion(itemKey: 'modrinth:root', versionId: 'root-v1', fileName: 'root.jar', fileId: 'root-file'),
        MtnMinecraftContentPackageLockedVersion(itemKey: 'modrinth:shared', versionId: 'shared-v1', fileName: 'shared.jar', fileId: 'shared-file'),
      ],
      edges: <MtnMinecraftContentPackageLockedEdge>[
        MtnMinecraftContentPackageLockedEdge(sourceKey: 'modrinth:root', targetKey: 'modrinth:shared', type: MtnMinecraftContentDependencyType.required),
      ],
    );
    final package = pack(items: <MtnMinecraftContentPackageItem>[root, dep], lock: locked);
    expect(package.add(release(project('shared'), 'shared-v1')), isTrue);
    expect(package.items.length, 2);
    expect(dep.direct, isTrue);
    expect(dep.canDisable, isTrue);
    expect(package.remove(dep), isTrue);
    expect(dep.direct, isFalse);
    expect(dep.effectiveEnabled, isTrue);
    expect(dep.toLocalMap()['direct'], isFalse);
    expect(MtnMinecraftContentPackage.fromLocalMap(package.toLocalMap()).getItem(dep.key)!.direct, isFalse);
    root.enabled = false;
    expect(dep.effectiveEnabled, isFalse);
  });

}
