import 'package:minecraft_content_service/minecraft_content_service.dart';
import 'package:test/test.dart';

void main() {
  test('project-only dependency reuses the selected compatible version and builds reverse edges', () async {
    final architectury = _content('lhGA9TYQ', 'Architectury API');
    final rei = _content('rei', 'Roughly Enough Items');
    final pinned = _version(architectury, 'arch-pinned', '20.1.18+fabric');
    final latest = _version(architectury, 'arch-newer', '20.2.19+fabric');
    final root = _version(rei, 'rei-exact', '26.1.819+fabric', dependencies: [
      MtnMinecraftContentDependency(
        type: MtnMinecraftContentDependencyType.required,
        provider: 'modrinth', providerContentId: 'lhGA9TYQ',
      ),
    ]);
    final provider = _Provider([architectury, rei], [root, pinned, latest],
      listed: {'lhGA9TYQ': [latest]});
    final service = MtnMinecraftContentService(providers: [provider]);
    final package = _package([
      _item(rei, 'rei-exact', direct: true),
      _item(architectury, 'arch-pinned', direct: false),
    ]);

    final desired = await package.resolveDependencies(service);
    expect(desired.installable, isTrue);
    expect(desired.installVersions.map((version) => version.key),
      ['version:rei-exact', 'version:arch-pinned']);
    expect(provider.versionListCalls, 0);
    expect(package.rebuildLock(desired, selectedFilesByVersionKey: {
      for (final version in desired.installVersions) version.key: version.files.single,
    }), isTrue);
    expect(package.lock!.edges, hasLength(1));
    expect(package.lock!.edges.single.sourceKey, 'modrinth:rei');
    expect(package.lock!.edges.single.targetKey, 'modrinth:lhGA9TYQ');
    expect(package.getItem('modrinth:lhGA9TYQ')!.direct, isFalse);
  });

  test('an exact dependency ID overrides the package preference', () async {
    final architectury = _content('lhGA9TYQ', 'Architectury API');
    final pinned = _version(architectury, 'arch-pinned', '20.1.18+fabric');
    final required = _version(architectury, 'arch-required', '20.2.19+fabric');
    final service = MtnMinecraftContentService(providers: [
      _Provider([architectury], [pinned, required], listed: {'lhGA9TYQ': [required]})
    ]);
    final result = await service.resolveDependencyVersion(
      MtnMinecraftContentDependency(
        type: MtnMinecraftContentDependencyType.required,
        provider: 'modrinth', providerContentId: 'lhGA9TYQ',
        providerVersionId: 'arch-required',
      ),
      _request({'modrinth:lhGA9TYQ': 'arch-pinned'}),
    );
    expect(result.version?.key, required.key);
  });

  test('a version constraint does not reuse a pin without constraint validation', () async {
    final architectury = _content('lhGA9TYQ', 'Architectury API');
    final pinned = _version(architectury, 'arch-pinned', '20.1.18+fabric');
    final newer = _version(architectury, 'arch-newer', '20.2.19+fabric');
    final provider = _Provider([architectury], [pinned, newer],
        listed: {'lhGA9TYQ': [newer]});
    final service = MtnMinecraftContentService(providers: [provider]);
    final result = await service.resolveDependencyVersion(
      MtnMinecraftContentDependency(
        type: MtnMinecraftContentDependencyType.required,
        provider: 'modrinth', providerContentId: 'lhGA9TYQ',
        versionConstraint: '>=20.2',
      ),
      _request({'modrinth:lhGA9TYQ': 'arch-pinned'}),
    );
    expect(result.version?.key, newer.key);
    expect(provider.versionListCalls, 1);
  });

  test('incompatible pinned game version falls back to compatible provider release', () async {
    final architectury = _content('lhGA9TYQ', 'Architectury API');
    final pinned = _version(architectury, 'arch-old', 'old',
        gameVersions: ['1.20.1']);
    final compatible = _version(architectury, 'arch-new', 'new');
    final provider = _Provider([architectury], [pinned, compatible],
        listed: {'lhGA9TYQ': [compatible]});
    final service = MtnMinecraftContentService(providers: [provider]);
    final result = await service.resolveDependencyVersion(
      MtnMinecraftContentDependency(
        type: MtnMinecraftContentDependencyType.required,
        provider: 'modrinth', providerContentId: 'lhGA9TYQ',
      ),
      _request({'modrinth:lhGA9TYQ': 'arch-old'}),
    );
    expect(result.version?.key, compatible.key);
    expect(provider.versionListCalls, 1);
  });

  test('wrong-project preferred version is rejected, not installed', () async {
    final architectury = _content('lhGA9TYQ', 'Architectury API');
    final other = _content('other', 'Unrelated mod');
    final wrong = _version(other, 'wrong-version', 'other');
    final service = MtnMinecraftContentService(providers: [
      _Provider([architectury, other], [wrong], listed: {'lhGA9TYQ': []}),
    ]);
    await expectLater(
      service.resolveDependencyVersion(
        MtnMinecraftContentDependency(
          type: MtnMinecraftContentDependencyType.required,
          provider: 'modrinth', providerContentId: 'lhGA9TYQ',
        ),
        _request({'modrinth:lhGA9TYQ': 'wrong-version'}),
      ),
      throwsFormatException,
    );
  });
}

MtnMinecraftContentVersionSelectionRequest _request(Map<String, String> preferred) =>
    MtnMinecraftContentVersionSelectionRequest(
      gameVersions: ['26.1.2'],
      modLoaders: [MtnMinecraftModLoaderType.fabric],
      preferredVersionIdsByContent: preferred,
    );

MtnMinecraftContentMod _content(String id, String name) =>
    MtnMinecraftContentMod(key: 'modrinth:$id', name: name,
      providers: [MtnMinecraftContentProviderMetadata(provider: 'modrinth', id: id)]);

MtnMinecraftContentVersion _version(MtnMinecraftContent content, String id,
    String name, {List<String> gameVersions = const ['26.1.2'],
    List<MtnMinecraftContentDependency> dependencies = const []}) =>
    MtnMinecraftContentVersion(
      key: 'version:$id', content: content,
      name: name, version: name,
      providers: [MtnMinecraftContentProviderMetadata(provider: 'modrinth', id: id)],
      releaseType: MtnMinecraftContentVersionReleaseType.release,
      gameVersions: gameVersions,
      modLoaders: [MtnMinecraftModLoaderType.fabric],
      files: [MtnMinecraftContentFile(fileName: '$id.jar', primary: true,
          available: true, size: 2,
          hashes: [MtnMinecraftContentFileHash(algorithm: 'sha1', value: 'a' * 40)])],
      dependencies: dependencies,
    );

MtnMinecraftContentPackageItem _item(MtnMinecraftContent content,
    String versionId, {required bool direct}) =>
    MtnMinecraftContentPackageItem(
      provider: 'modrinth',
      projectId: content.providers.single.id!,
      type: MtnMinecraftContentType.mod, title: content.name,
      direct: direct, source: MtnMinecraftContentPackageSource.local,
      selectedVersionId: versionId,
      permissions: MtnMinecraftContentItemPermission.values,
    );

MtnMinecraftContentPackage _package(List<MtnMinecraftContentPackageItem> items) =>
    MtnMinecraftContentPackage(
      id: 'dependency-demo', title: 'Dependency demo', items: items,
      minecraftVersion: '26.1.2', modLoader: MtnMinecraftModLoaderType.fabric,
      loaderVersion: '0.20.1', ramMiB: 4096, ownerName: 'Tester',
      createdAt: DateTime.utc(2026, 11, 1), updatedAt: DateTime.utc(2026, 11, 2),
    );

class _Provider extends MtnMinecraftContentProvider {
  _Provider(List<MtnMinecraftContent> contents,
      List<MtnMinecraftContentVersion> versions,
      {required this.listed})
      : contents = {for (final value in contents) value.providers.single.id!: value},
        versions = {for (final value in versions) value.providers.single.id!: value},
        super(name: 'modrinth');

  final Map<String, MtnMinecraftContent> contents;
  final Map<String, MtnMinecraftContentVersion> versions;
  final Map<String, List<MtnMinecraftContentVersion>> listed;
  int versionListCalls = 0;

  @override
  bool get ready => true;

  @override
  Future<MtnMinecraftContent> getContent(String id) async => contents[id]!;
  @override
  Future<MtnMinecraftContentVersion> getVersion(String id) async => versions[id]!;

  @override
  Future<MtnMinecraftContentVersionListResult> getVersions(
      MtnMinecraftContent content,
      MtnMinecraftContentVersionListRequest request) async {
    versionListCalls++;
    final selected = listed[content.providers.single.id] ?? const <MtnMinecraftContentVersion>[];
    return MtnMinecraftContentVersionListResult(
      versions: selected, offset: request.offset, limit: request.limit, hasMore: false,
    );
  }

  @override
  Future<MtnMinecraftContentSearchResult> search(MtnMinecraftContentSearchRequest request) async =>
      MtnMinecraftContentSearchResult(
        provider: name, contents: [], offset: request.offset, limit: request.limit,
        hasMore: false,
      );
}
