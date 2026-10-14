import 'package:minecraft_content_service/minecraft_content_service.dart';
import 'package:test/test.dart';

MtnMinecraftContentVersion release(String id) {
  final content = MtnMinecraftContentMod(
    key: 'modrinth:$id', name: id,
    providers: <MtnMinecraftContentProviderMetadata>[MtnMinecraftContentProviderMetadata(provider: 'modrinth', id: id)],
  );
  return MtnMinecraftContentVersion(
    key: 'version:$id', name: id, version: '1.0.0', content: content,
    releaseType: MtnMinecraftContentVersionReleaseType.release,
    gameVersions: <String>['1.21.11'],
    modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
    providers: <MtnMinecraftContentProviderMetadata>[
      MtnMinecraftContentProviderMetadata(provider: 'modrinth', id: 'version-$id'),
    ],
    files: <MtnMinecraftContentFile>[
      MtnMinecraftContentFile(
        fileName: '$id.jar', size: 42, available: true, primary: true,
        hashes: <MtnMinecraftContentFileHash>[
          MtnMinecraftContentFileHash(algorithm: 'sha1', value: 'a' * 40),
        ],
      ),
    ],
  );
}

MtnMinecraftContentDependencyGraphEdge edge(
  MtnMinecraftContentVersion from, MtnMinecraftContentVersion to, {
  MtnMinecraftContentDependencyType type = MtnMinecraftContentDependencyType.required,
}) {
  final dependency = MtnMinecraftContentDependency(type: type, provider: 'modrinth', providerContentId: to.content.providers.single.id);
  return MtnMinecraftContentDependencyGraphEdge(
    source: from, dependency: dependency,
    resolution: MtnMinecraftContentDependencyResolution(dependency: dependency, version: to),
    target: to, cyclic: false,
  );
}

class GraphService extends MtnMinecraftContentService {
  GraphService(this.graphs);
  final Map<String, MtnMinecraftContentDependencyGraph> graphs;

  @override
  Future<MtnMinecraftContentDependencyGraph> resolveDependencyGraph(
    MtnMinecraftContentVersion root,
    MtnMinecraftContentVersionSelectionRequest request,
  ) async {
    if (!request.gameVersions.contains('1.21.11') || !request.modLoaders.contains(MtnMinecraftModLoaderType.fabric)) {
      throw StateError('Package version / loader scope not passed to dependency resolver.');
    }
    return graphs[root.key]!;
  }
}

MtnMinecraftContentPackage packageDraft({
  MtnMinecraftContentPackageMutationPolicy policy = MtnMinecraftContentPackageMutationPolicy.none,
  int revision = 2,
}) => MtnMinecraftContentPackage(
  id: 'pack-1', title: 'Fabric Package',
  minecraftVersion: '1.21.11', modLoader: MtnMinecraftModLoaderType.fabric,
  loaderVersion: '0.16.14', ramMiB: 4096, ownerName: 'Publisher',
  createdAt: DateTime.utc(2026, 10, 13), updatedAt: DateTime.utc(2026, 10, 14),
  revision: revision, mutationPolicy: policy, items: const <MtnMinecraftContentPackageItem>[],
);

void main() {
  test('two selected roots rebuild an exact portable lock with one shared dependency', () async {
    final a = release('a');
    final b = release('b');
    final shared = release('shared');
    final package = packageDraft();
    expect(package.add(a), isTrue);
    expect(package.add(b), isTrue);
    final aItem = package.getItem('modrinth:a')!;
    final bItem = package.getItem('modrinth:b')!;

    final service = GraphService(<String, MtnMinecraftContentDependencyGraph>{
      a.key: MtnMinecraftContentDependencyGraph(root: a, versions: <MtnMinecraftContentVersion>[a, shared], edges: <MtnMinecraftContentDependencyGraphEdge>[edge(a, shared)]),
      b.key: MtnMinecraftContentDependencyGraph(root: b, versions: <MtnMinecraftContentVersion>[b, shared], edges: <MtnMinecraftContentDependencyGraphEdge>[edge(b, shared)]),
    });
    final desired = await package.resolveDependencies(service);
    expect(desired.installable, isTrue);
    expect(package.lock, isNull);
    expect(package.items.length, 2);
    expect(package.rebuildLock(
      desired,
      selectedFilesByVersionKey: <String, MtnMinecraftContentFile>{
        for (final version in desired.installVersions) version.key: version.files.single,
      },
    ), isTrue);
    expect(package.lock!.versions.length, 3);
    expect(package.lock!.edges.length, 2);
    expect(package.items.length, 3);
    expect(package.getItem('modrinth:a'), same(aItem));
    expect(package.getItem('modrinth:b'), same(bItem));
    expect(package.getItem('modrinth:shared')!.direct, isFalse);
    expect(identical(package.getItem('modrinth:shared')!.package, package), isTrue);
    expect(package.getItem('modrinth:shared')!.source, MtnMinecraftContentPackageSource.local);
    expect(package.getItem('modrinth:shared')!.effectiveEnabled, isTrue);

    aItem.enabled = false;
    expect(package.getItem('modrinth:shared')!.effectiveEnabled, isTrue);
    bItem.enabled = false;
    expect(package.getItem('modrinth:shared')!.effectiveEnabled, isFalse);
    final portable = MtnMinecraftContentPackage.decode(package.encode());
    expect(portable.lock!.versions.length, 3);
    expect(portable.getItem('modrinth:shared')!.effectiveEnabled, isFalse);
  });

  test('explicit optional dependency only enters the final exact lock when selected', () async {
    final root = release('root');
    final optional = release('optional');
    final package = packageDraft();
    expect(package.add(root), isTrue);
    final service = GraphService(<String, MtnMinecraftContentDependencyGraph>{
      root.key: MtnMinecraftContentDependencyGraph(root: root, versions: <MtnMinecraftContentVersion>[root, optional], edges: <MtnMinecraftContentDependencyGraphEdge>[
        edge(root, optional, type: MtnMinecraftContentDependencyType.optional),
      ]),
    });
    final without = await package.resolveDependencies(service);
    expect(without.installVersions.length, 1);
    expect(without.installable, isTrue);
    final withOptional = await package.resolveDependencies(service, selectedOptionalVersionKeysByRoot: <String, List<String>>{
      root.key: <String>[optional.key],
    });
    expect(withOptional.installable, isTrue);
    expect(withOptional.installVersions.length, 2);
    expect(package.rebuildLock(withOptional, selectedFilesByVersionKey: <String, MtnMinecraftContentFile>{
      for (final version in withOptional.installVersions) version.key: version.files.single,
    }), isTrue);
    expect(package.lock!.edges.single.type, MtnMinecraftContentDependencyType.optional);
    expect(package.getItem('modrinth:optional')!.effectiveEnabled, isTrue);
  });

  test('incomplete explicit file choices do not mutate package or selected roots', () async {
    final root = release('root');
    final package = packageDraft();
    expect(package.add(root), isTrue);
    final service = GraphService(<String, MtnMinecraftContentDependencyGraph>{
      root.key: MtnMinecraftContentDependencyGraph(root: root, versions: <MtnMinecraftContentVersion>[root], edges: <MtnMinecraftContentDependencyGraphEdge>[]),
    });
    final desired = await package.resolveDependencies(service);
    final original = package.items.single;
    final before = package.toLocalMap();
    expect(() => package.rebuildLock(desired, selectedFilesByVersionKey: <String, MtnMinecraftContentFile>{}), throwsArgumentError);
    expect(package.toLocalMap(), before);
    expect(package.lock, isNull);
    expect(package.items.single, same(original));
    expect(identical(original.package, package), isTrue);
  });

  test('downloaded package has transient newRevisionNum without overriding installed revision', () {
    final package = packageDraft(revision: 4);
    expect(package.revision, 4);
    expect(package.revisionNum, 4);
    expect(package.newRevisionNum, isNull);
    expect(package.updateAvail, isFalse);
    package.newRevisionNum = 5;
    expect(package.newRevisionNum, isNull); // Local package cannot receive a remote update marker.
    MtnMinecraftContentPackageRecord(package: package, source: MtnMinecraftContentPackageSource.downloaded, remoteId: 'published-pack', publishedRevision: 4);
    package.newRevisionNum = 4;
    expect(package.updateAvail, isFalse);
    expect(package.newRevisionNum, isNull);
    package.newRevisionNum = 3;
    expect(package.updateAvail, isFalse);
    package.newRevisionNum = 6;
    expect(package.newRevisionNum, 6);
    expect(package.updateAvail, isTrue);
    expect(package.revisionNum, 4);
    expect(package.toLocalMap().containsKey('newRevisionNum'), isFalse);
    final serialized = package.record!.toMap();
    expect(serialized.containsKey('newRevisionNum'), isFalse);
    final restored = MtnMinecraftContentPackageRecord.fromMap(serialized).package;
    expect(restored.revisionNum, 4);
    expect(restored.newRevisionNum, isNull);
    expect(restored.updateAvail, isFalse);
    package.newRevisionNum = null;
    expect(package.updateAvail, isFalse);
  });
}
