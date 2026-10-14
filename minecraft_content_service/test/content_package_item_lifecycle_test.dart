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
    await package.checkUpdates(VersionService(content, old, <MtnMinecraftContentVersion>[old, latest]));
    expect(item.canUpdate, isTrue);
    expect(package.updateList[item], same(latest));
    expect(item.toLocalMap().containsKey('updateVersion'), isFalse);
    expect(package.toLocalMap().containsKey('updateList'), isFalse);
    expect(package.remove(item), isTrue);
    expect(package.updateList, isEmpty);
  });
}
