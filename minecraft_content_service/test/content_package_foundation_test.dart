import 'package:minecraft_content_service/minecraft_content_service.dart';
import 'package:test/test.dart';

MtnMinecraftContentPackageItem item(
  String id, {
  bool direct = false,
  bool enabled = true,
  String? title,
  MtnMinecraftContentType type = MtnMinecraftContentType.mod,
  Iterable<MtnMinecraftContentItemPermission> permissions = const <MtnMinecraftContentItemPermission>[],
}) {
  return MtnMinecraftContentPackageItem(
    provider: 'modrinth',
    projectId: id,
    title: title ?? id,
    type: type,
    direct: direct,
    enabled: enabled,
    permissions: permissions,
  );
}

MtnMinecraftContentPackageLock graph({bool cycle = false}) {
  return MtnMinecraftContentPackageLock(
    versions: <MtnMinecraftContentPackageLockedVersion>[
      for (final id in <String>['a', 'b', 'c', 'x'])
        MtnMinecraftContentPackageLockedVersion(itemKey: 'modrinth:$id', versionId: 'version-$id', fileName: '$id.jar', fileId: 'file-$id'),
    ],
    edges: <MtnMinecraftContentPackageLockedEdge>[
      MtnMinecraftContentPackageLockedEdge(sourceKey: 'modrinth:a', targetKey: 'modrinth:b', type: MtnMinecraftContentDependencyType.required),
      MtnMinecraftContentPackageLockedEdge(sourceKey: 'modrinth:x', targetKey: 'modrinth:b', type: MtnMinecraftContentDependencyType.required),
      MtnMinecraftContentPackageLockedEdge(sourceKey: 'modrinth:b', targetKey: 'modrinth:c', type: MtnMinecraftContentDependencyType.optional),
      if (cycle) MtnMinecraftContentPackageLockedEdge(sourceKey: 'modrinth:c', targetKey: 'modrinth:b', type: MtnMinecraftContentDependencyType.required),
    ],
  );
}

MtnMinecraftContentPackage contentPackage({
  bool aEnabled = true,
  bool xEnabled = true,
  MtnMinecraftContentPackageMutationPolicy policy = MtnMinecraftContentPackageMutationPolicy.none,
  bool cycle = false,
}) {
  return MtnMinecraftContentPackage(
    id: 'my-pack',
    title: 'Test pack',
    minecraftVersion: '1.21.11',
    modLoader: MtnMinecraftModLoaderType.fabric,
    mutationPolicy: policy,
    revision: 3,
    items: <MtnMinecraftContentPackageItem>[
      item('x', title: 'X Resource', type: MtnMinecraftContentType.resourcePack, direct: true, enabled: xEnabled, permissions: MtnMinecraftContentItemPermission.values),
      item('c', title: 'C Library'),
      item('b', title: 'B Library'),
      item('a', title: 'A Mod', direct: true, enabled: aEnabled, permissions: MtnMinecraftContentItemPermission.values),
    ],
    lock: graph(cycle: cycle),
  );
}

class FakeContentService extends MtnMinecraftContentService {
  FakeContentService(this.found);

  final Map<String, MtnMinecraftContent> found;
  final Map<String, int> calls = <String, int>{};

  @override
  Future<MtnMinecraftContent> getContent(String providerName, String id) async {
    final key = '$providerName:$id';
    calls[key] = (calls[key] ?? 0) + 1;
    final result = found[key];
    if (result == null) throw StateError('Missing item $key');
    return result;
  }
}

void main() {
  test('published package round-trips exact lock, metadata and permissions without runtime state', () {
    final original = contentPackage(aEnabled: false);
    final directItem = original.getItem('modrinth:a')!;
    expect(directItem.directEnabled, isFalse);
    final exported = original.toJson();

    expect(exported, isNot(contains('"state"')));
    expect(exported, isNot(contains('"loadError"')));
    expect(exported, isNot(contains('"content"')));
    expect(exported, contains('"version-a"'));
    expect(exported, contains('"file-a"'));

    final imported = MtnMinecraftContentPackage.decode(original.encode());
    expect(imported.toJson(), exported);
    expect(imported.id, 'my-pack');
    expect(imported.revision, 3);
    expect(imported.mutationPolicy, MtnMinecraftContentPackageMutationPolicy.none);
    expect(imported.lock!.versions.length, 4);
    expect(imported.lock!.edges.length, 3);
    expect(imported.items.every((value) => value.state == MtnMinecraftContentItemState.notLoaded), isTrue);
    expect(imported.getItem('modrinth:a')!.directEnabled, isFalse);
    expect(imported.getItem('modrinth:a')!.canUpdate, isTrue);
    expect(imported.getItem('modrinth:b')!.canEnable, isFalse);
  });

  test('views separate direct roots and shared dependencies while sorting only snapshots', () {
    final package = contentPackage();
    expect(package.items.first.projectId, 'x');
    expect(package.directItems.map((value) => value.title).toList(), <String>['A Mod', 'X Resource']);
    expect(package.allItems.map((value) => value.title).toList(), <String>['A Mod', 'B Library', 'C Library', 'X Resource']);
    expect(package.items.first.projectId, 'x');
    expect(() => package.allItems.clear(), throwsUnsupportedError);

    final tree = package.treeItems;
    expect(tree.length, 2);
    expect(tree[0].item.key, 'modrinth:a');
    expect(tree[1].item.key, 'modrinth:x');
    expect(tree[0].children.single.item.key, 'modrinth:b');
    expect(tree[1].children.single.item.key, 'modrinth:b');
    expect(tree[0].children.single.children.single.item.key, 'modrinth:c');
  });

  test('transitive shared dependencies are enabled iff reachable from active direct roots', () {
    final package = contentPackage();
    final a = package.getItem('modrinth:a')!;
    final x = package.getItem('modrinth:x')!;
    final b = package.getItem('modrinth:b')!;
    final c = package.getItem('modrinth:c')!;

    expect(package.effectiveEnabled(b), isTrue);
    package.setDirectEnabled(a, false);
    expect(package.effectiveEnabled(b), isTrue);
    expect(package.effectiveEnabled(c), isTrue);
    package.setDirectEnabled(x, false);
    expect(package.effectiveEnabled(b), isFalse);
    expect(package.effectiveEnabled(c), isFalse);
    package.setDirectEnabled(a, true);
    expect(package.effectiveEnabled(b), isTrue);
    expect(package.effectiveEnabled(c), isTrue);
    expect(() => package.setDirectEnabled(b, false), throwsStateError);
    expect(() => b.setDirectEnabled(false), throwsStateError);
  });

  test('cyclic dependency tree terminates without losing the cycle marker', () {
    final package = contentPackage(cycle: true);
    final c = package.treeItems.first.children.single.children.single;
    expect(c.item.key, 'modrinth:c');
    expect(c.children.single.cyclic, isTrue);
    expect(c.children.single.item.key, 'modrinth:b');
    expect(c.children.single.children, isEmpty);
  });

  test('package and item mutation permissions enforce distinct policies', () {
    final normal = contentPackage();
    final readOnly = contentPackage(policy: MtnMinecraftContentPackageMutationPolicy.readOnly);
    final appendOnly = contentPackage(policy: MtnMinecraftContentPackageMutationPolicy.appendOnly);
    expect(normal.canAdd, isTrue);
    expect(normal.canRemove(normal.getItem('modrinth:a')!), isTrue);
    expect(normal.canUpdate(normal.getItem('modrinth:a')!), isTrue);
    expect(normal.canRemove(normal.getItem('modrinth:b')!), isFalse);
    expect(readOnly.canAdd, isFalse);
    expect(readOnly.canRemove(readOnly.getItem('modrinth:a')!), isFalse);
    expect(readOnly.canUpdate(readOnly.getItem('modrinth:a')!), isTrue);
    expect(appendOnly.canAdd, isTrue);
    expect(appendOnly.canRemove(appendOnly.getItem('modrinth:a')!), isFalse);
  });

  test('unlocked draft export and incomplete graphs are rejected', () {
    final a = item('a', direct: true);
    final draft = MtnMinecraftContentPackage(id: 'draft', title: 'Draft', minecraftVersion: '1.21.11', modLoader: MtnMinecraftModLoaderType.fabric, items: <MtnMinecraftContentPackageItem>[a]);
    expect(() => draft.encode(), throwsStateError);

    expect(
      () => MtnMinecraftContentPackage(
        id: 'broken', title: 'Broken', minecraftVersion: '1.21.11', modLoader: MtnMinecraftModLoaderType.fabric,
        items: <MtnMinecraftContentPackageItem>[a, item('b')],
        lock: MtnMinecraftContentPackageLock(
          versions: <MtnMinecraftContentPackageLockedVersion>[
            MtnMinecraftContentPackageLockedVersion(itemKey: 'modrinth:a', versionId: 'v-a', fileName: 'a.jar', fileId: 'file-a'),
            MtnMinecraftContentPackageLockedVersion(itemKey: 'modrinth:b', versionId: 'v-b', fileName: 'b.jar', fileId: 'file-b'),
          ],
          edges: const <MtnMinecraftContentPackageLockedEdge>[],
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => MtnMinecraftContentPackage.fromJson('{"schemaVersion":2}'),
      throwsFormatException,
    );
  });

  test('provider hydration is transient, verifies identity, and retries errors', () async {
    final a = item('a', direct: true);
    final service = FakeContentService(<String, MtnMinecraftContent>{
      'modrinth:a': MtnMinecraftContentMod(
        key: 'a', name: 'A Mod',
        providers: <MtnMinecraftContentProviderMetadata>[
          MtnMinecraftContentProviderMetadata(provider: 'modrinth', id: 'a'),
        ],
      ),
    });
    await a.hydrate(service);
    expect(a.state, MtnMinecraftContentItemState.loaded);
    expect(a.content, isNotNull);
    await a.hydrate(service);
    expect(service.calls['modrinth:a'], 1);
    expect(a.toMap().containsKey('state'), isFalse);

    final missing = item('missing');
    await expectLater(missing.hydrate(service), throwsStateError);
    expect(missing.state, MtnMinecraftContentItemState.error);
    expect(missing.loadError, isNotNull);
    service.found['modrinth:missing'] = MtnMinecraftContentMod(
      key: 'missing', name: 'Recovered',
      providers: <MtnMinecraftContentProviderMetadata>[
        MtnMinecraftContentProviderMetadata(provider: 'modrinth', id: 'missing'),
      ],
    );
    await missing.hydrate(service);
    expect(missing.state, MtnMinecraftContentItemState.loaded);
    expect(missing.loadError, isNull);
    expect(service.calls['modrinth:missing'], 2);
  });

  test('locked artifact accepts portable SHA-1 and rejects invalid hash pairs', () {
    final version = MtnMinecraftContentPackageLockedVersion(
      itemKey: 'modrinth:a', versionId: 'v1', fileName: 'a.jar',
      hashAlgorithm: 'sha1', hashValue: 'a' * 40,
    );
    expect(MtnMinecraftContentPackageLockedVersion.fromMap(version.toMap()).hashValue, 'a' * 40);
    expect(
      () => MtnMinecraftContentPackageLockedVersion(itemKey: 'modrinth:a', versionId: 'v1', fileName: 'a.jar'),
      throwsArgumentError,
    );
  });
}
