import 'package:minecraft_content_service/minecraft_content_service.dart';
import 'package:test/test.dart';

MtnMinecraftContentMod content(String id) => MtnMinecraftContentMod(
  key: 'test:$id', name: id,
  providers: <MtnMinecraftContentProviderMetadata>[
    MtnMinecraftContentProviderMetadata(provider: 'test', id: id),
  ],
);

MtnMinecraftContentVersion version(String contentId, String versionId, DateTime published) {
  final item = content(contentId);
  return MtnMinecraftContentVersion(
    key: 'test:$versionId', content: item, name: versionId, version: versionId,
    releaseType: MtnMinecraftContentVersionReleaseType.release,
    gameVersions: const <String>['1.21.11'],
    modLoaders: const <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
    publishedAt: published,
    providers: <MtnMinecraftContentProviderMetadata>[
      MtnMinecraftContentProviderMetadata(provider: 'test', id: versionId),
    ],
    files: <MtnMinecraftContentFile>[
      MtnMinecraftContentFile(
        fileName: '$versionId.jar', size: 20, primary: true,
        hashes: <MtnMinecraftContentFileHash>[
          MtnMinecraftContentFileHash(algorithm: 'sha1', value: 'a' * 40),
        ],
      ),
    ],
  );
}

MtnMinecraftContentDependencyGraphEdge requiredEdge(MtnMinecraftContentVersion root, MtnMinecraftContentVersion dependency) {
  final declared = MtnMinecraftContentDependency(
    type: MtnMinecraftContentDependencyType.required,
    provider: 'test', providerContentId: dependency.content.providers.single.id,
  );
  return MtnMinecraftContentDependencyGraphEdge(
    source: root, dependency: declared,
    resolution: MtnMinecraftContentDependencyResolution(dependency: declared, version: dependency),
    target: dependency, cyclic: false,
  );
}

class _AutoUpdateService extends MtnMinecraftContentService {
  _AutoUpdateService(this.versions, this.available, this.graphs, {this.onResolve});

  final Map<String, MtnMinecraftContentVersion> versions;
  final Map<String, List<MtnMinecraftContentVersion>> available;
  final Map<String, MtnMinecraftContentDependencyGraph> graphs;
  final void Function()? onResolve;

  @override
  Future<MtnMinecraftContent> getContent(String providerName, String projectId) async {
    if (providerName != 'test') throw StateError('Unexpected provider: $providerName');
    return content(projectId);
  }

  @override
  Future<MtnMinecraftContentVersion> getVersion(String providerName, String id) async =>
      versions[id] ?? (throw StateError('Missing provider version: $id'));

  @override
  Future<MtnMinecraftContentVersionListResult> getVersions(
    String providerName, MtnMinecraftContent item, MtnMinecraftContentVersionListRequest request,
  ) async => MtnMinecraftContentVersionListResult(
    versions: available[item.providers.single.id] ?? <MtnMinecraftContentVersion>[],
    offset: request.offset, limit: request.limit, hasMore: false,
  );

  @override
  Future<MtnMinecraftContentDependencyGraph> resolveDependencyGraph(
    MtnMinecraftContentVersion root, MtnMinecraftContentVersionSelectionRequest request,
  ) async {
    onResolve?.call();
    if (request.gameVersions.single != '1.21.11' || !request.modLoaders.contains(MtnMinecraftModLoaderType.fabric)) {
      throw StateError('Wrong dependency resolver scope.');
    }
    return graphs[root.key] ?? (throw StateError('No dependency graph for ${root.key}'));
  }
}

MtnMinecraftContentPackage makePackage() {
  final a = MtnMinecraftContentPackageItem(
    provider: 'test', projectId: 'a', title: 'A', type: MtnMinecraftContentType.mod,
    direct: true, selectedVersionId: 'a-old',
    permissions: MtnMinecraftContentItemPermission.values,
  );
  final b = MtnMinecraftContentPackageItem(
    provider: 'test', projectId: 'b', title: 'B', type: MtnMinecraftContentType.mod,
    direct: true, selectedVersionId: 'b-old',
    permissions: MtnMinecraftContentItemPermission.values,
  );
  final dependency = MtnMinecraftContentPackageItem(
    provider: 'test', projectId: 'library', title: 'Library', type: MtnMinecraftContentType.mod,
    direct: false, selectedVersionId: 'library-old',
  );
  return MtnMinecraftContentPackage(
    id: 'auto-update-test', title: 'Installed Fabric', minecraftVersion: '1.21.11',
    modLoader: MtnMinecraftModLoaderType.fabric, loaderVersion: '0.16.14',
    ramMiB: 4096, ownerName: 'Test',
    createdAt: DateTime.utc(2026, 10, 1), updatedAt: DateTime.utc(2026, 10, 2),
    items: <MtnMinecraftContentPackageItem>[a, b, dependency],
    dependencyEdges: <MtnMinecraftContentPackageLockedEdge>[
      MtnMinecraftContentPackageLockedEdge(
        sourceKey: a.key, targetKey: dependency.key, type: MtnMinecraftContentDependencyType.required,
      ),
    ],
  );
}

void main() {
  final old = DateTime.utc(2026, 1, 1);
  final fresh = DateTime.utc(2026, 10, 1);
  final aOld = version('a', 'a-old', old);
  final aNew = version('a', 'a-new', fresh);
  final bOld = version('b', 'b-old', old);
  final libraryOld = version('library', 'library-old', old);
  final libraryNew = version('library', 'library-new', fresh);

  _AutoUpdateService service({bool conflict = false, void Function()? onResolve}) => _AutoUpdateService(
    <String, MtnMinecraftContentVersion>{
      for (final item in <MtnMinecraftContentVersion>[aOld, aNew, bOld, libraryOld, libraryNew])
        item.providers.single.id!: item,
    },
    <String, List<MtnMinecraftContentVersion>>{
      'a': <MtnMinecraftContentVersion>[aOld, aNew],
      'b': <MtnMinecraftContentVersion>[bOld],
    },
    <String, MtnMinecraftContentDependencyGraph>{
      aNew.key: MtnMinecraftContentDependencyGraph(
        root: aNew, versions: <MtnMinecraftContentVersion>[aNew, libraryNew],
        edges: <MtnMinecraftContentDependencyGraphEdge>[requiredEdge(aNew, libraryNew)],
      ),
      bOld.key: MtnMinecraftContentDependencyGraph(
        root: bOld,
        versions: conflict ? <MtnMinecraftContentVersion>[bOld, libraryOld] : <MtnMinecraftContentVersion>[bOld],
        edges: conflict ? <MtnMinecraftContentDependencyGraphEdge>[requiredEdge(bOld, libraryOld)] : <MtnMinecraftContentDependencyGraphEdge>[],
      ),
    },
    onResolve: onResolve,
  );

  test('prepares updated root and new dependency while retaining other pinned roots without changing source', () async {
    final original = makePackage();
    final beforeItem = original.getItem('test:a')!;
    original.getItem('test:b')!.autoUpdate = false;
    original.getItem('test:b')!.enabled = false;
    final provider = service();
    await original.checkUpdates(service: provider);
    expect(original.updateList.keys.map((item) => item.key), <String>['test:a']);
    final before = original.toLocalMap();

    final prepared = await const MtnMinecraftContentPackageAutoUpdatePlanner().prepare(original, provider);
    expect(prepared, isNotNull);
    expect(prepared!.updatedRoots.keys, <String>['test:a']);
    expect(prepared.package, isNot(same(original)));
    expect(prepared.package.lock, isNull);
    expect(prepared.package.items.length, 2); // Dependency-only old lock/pin removed from staging.
    expect(prepared.package.getItem('test:a')!.selectedVersionId, 'a-new');
    expect(prepared.package.getItem('test:b')!.selectedVersionId, 'b-old');
    expect(prepared.package.getItem('test:b')!.autoUpdate, isFalse);
    expect(prepared.package.getItem('test:b')!.enabled, isFalse);
    expect(prepared.desired.installable, isTrue);
    expect(prepared.desired.installVersions.map((v) => v.key).toSet(),
      <String>{aNew.key, bOld.key, libraryNew.key});

    expect(original.toLocalMap(), before);
    expect(original.getItem('test:a'), same(beforeItem));
    expect(original.getItem('test:a')!.selectedVersionId, 'a-old');
    expect(original.getItem('test:library')!.selectedVersionId, 'library-old');

    final selectedFiles = <String, MtnMinecraftContentFile>{
      for (final item in prepared.desired.installVersions) item.key: item.files.single,
    };
    expect(prepared.package.rebuildLock(prepared.desired, selectedFilesByVersionKey: selectedFiles), isTrue);
    expect(prepared.package.lock!.versions.map((v) => v.versionId).toSet(),
      <String>{'a-new', 'b-old', 'library-new'});
    expect(original.toLocalMap(), before); // Future install+save must publish the staged copy, never the source.
  });

  test('disabled direct roots are skipped by update checks and auto-application', () async {
    final original = makePackage();
    final a = original.getItem('test:a')!;
    final b = original.getItem('test:b')!;
    a.enabled = false;
    b.autoUpdate = false;
    expect(a.enabled, isFalse);
    expect(original.hasUpdateEligibleItems, isFalse);
    expect(original.needsUpdateCheck(), isFalse);

    final provider = service();
    await original.checkUpdates(service: provider, force: true);
    expect(original.updateList, isEmpty);
    expect(await const MtnMinecraftContentPackageAutoUpdatePlanner().prepare(original, provider), isNull);

    a.enabled = true;
    expect(original.needsUpdateCheck(), isTrue);
    await original.checkUpdates(service: provider);
    expect(original.updateList.keys.map((item) => item.key), <String>['test:a']);

    // A previously scanned candidate must disappear immediately after the
    // user disables the root, even without a second HTTP request.
    a.enabled = false;
    expect(original.updateList, isEmpty);
    expect(original.hasUpdateEligibleItems, isFalse);
    expect(await const MtnMinecraftContentPackageAutoUpdatePlanner().prepare(original, provider), isNull);
  });

  test('no compatible direct update returns null and leaves existing dependency pins untouched', () async {
    final original = makePackage();
    expect(await const MtnMinecraftContentPackageAutoUpdatePlanner().prepare(original, service()), isNull);
    expect(original.getItem('test:library')!.selectedVersionId, 'library-old');
    original.getItem('test:a')!.autoUpdate = false;
    await original.checkUpdates(service: service());
    expect(original.updateList, isEmpty);
    expect(await const MtnMinecraftContentPackageAutoUpdatePlanner().prepare(original, service()), isNull);
  });

  test('conflicting updated dependency graphs are rejected without changing the source package', () async {
    final original = makePackage();
    final provider = service(conflict: true);
    await original.checkUpdates(service: provider);
    final before = original.toLocalMap();
    await expectLater(
      const MtnMinecraftContentPackageAutoUpdatePlanner().prepare(original, provider),
      throwsStateError,
    );
    expect(original.toLocalMap(), before);
  });

  test('appendOnly added roots cannot upgrade protected downloaded dependency as a side effect', () async {
    final local = makePackage().toLocalMap();
    local['mutationPolicy'] = MtnMinecraftContentPackageMutationPolicy.appendOnly.name;
    local['items'] = <Map<String, dynamic>>[
      for (final Map<String, dynamic> raw in (local['items'] as List).cast<Map<String, dynamic>>())
        Map<String, dynamic>.from(raw)..['source'] =
          (raw['projectId'] == 'a' ? MtnMinecraftContentPackageSource.local : MtnMinecraftContentPackageSource.downloaded).name,
    ];
    final record = MtnMinecraftContentPackageRecord.fromMap(<String, dynamic>{
      'schemaVersion': MtnMinecraftContentPackageRecord.currentSchemaVersion,
      'source': MtnMinecraftContentPackageSource.downloaded.name,
      'package': local,
    });
    final original = record.package;
    final provider = service();
    await original.checkUpdates(service: provider);
    expect(original.updateList.keys.map((item) => item.key), <String>['test:a']);
    final before = original.toLocalMap();
    await expectLater(
      const MtnMinecraftContentPackageAutoUpdatePlanner().prepare(original, provider),
      throwsStateError,
    );
    expect(original.toLocalMap(), before);
    expect(original.getItem('test:library')!.selectedVersionId, 'library-old');
  });

  test('changing source preferences during graph resolution rejects the stale preparation', () async {
    final original = makePackage();
    final scanService = service();
    await original.checkUpdates(service: scanService);
    final provider = service(onResolve: () { original.getItem('test:a')!.autoUpdate = false; });
    await expectLater(
      const MtnMinecraftContentPackageAutoUpdatePlanner().prepare(original, provider),
      throwsStateError,
    );
    expect(original.getItem('test:a')!.selectedVersionId, 'a-old');
    expect(original.getItem('test:a')!.autoUpdate, isFalse);
  });
}
