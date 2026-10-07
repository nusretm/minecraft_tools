import 'package:minecraft_content_service/minecraft_content_service.dart';
import 'package:test/test.dart';

void main() {
  group('MtnMinecraftContentModel', () {
    test('serializes enums, dates and nested models', () {
      final metadata = MtnMinecraftContentProviderMetadata(
        provider: 'modrinth',
        id: 'project-a',
        metadata: <String, dynamic>{
          'createdAt': DateTime.utc(2026, 10, 7, 1, 2, 3),
          'releaseType': MtnMinecraftContentVersionReleaseType.release,
        },
      );

      final encoded = metadata.toJson();
      final decoded = MtnMinecraftContentModel.jsonDecode(encoded);

      expect(decoded['provider'], 'modrinth');
      expect(MtnMinecraftContentModel.mapFromMap(decoded['metadata'])['createdAt'], '2026-10-07T01:02:03.000Z');
      expect(MtnMinecraftContentModel.mapFromMap(decoded['metadata'])['releaseType'], 'release');
      expect(metadata.toString(), contains('provider=modrinth'));
    });
  });

  group('content specialization and versions', () {
    test('concrete content fixes its content type', () {
      final mod = MtnMinecraftContentMod(key: 'sodium', name: 'Sodium');
      final resourcePack = MtnMinecraftContentResourcePack(key: 'faithful', name: 'Faithful');

      expect(mod.type, MtnMinecraftContentType.mod);
      expect(resourcePack.type, MtnMinecraftContentType.resourcePack);
    });

    test('version uses latest registered version unless explicitly selected', () {
      final list = MtnMinecraftContentList();
      final content = MtnMinecraftContentMod(key: 'fabric-api', name: 'Fabric API');
      final v14 = MtnMinecraftContentVersion(
        key: 'fabric-api-14',
        content: content,
        name: 'Fabric API 14',
        version: '14',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
      );
      final v15 = MtnMinecraftContentVersion(
        key: 'fabric-api-15',
        content: content,
        name: 'Fabric API 15',
        version: '15',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric, MtnMinecraftModLoaderType.quilt],
      );

      list.addContent(content);
      list.addVersion(v14);
      list.addVersion(v15);

      expect(content.version, same(v15));

      content.version = v14;
      expect(content.version, same(v14));

      content.version = null;
      expect(content.version, same(v15));
    });

    test('non-mod content versions are vanilla only', () {
      final resourcePack = MtnMinecraftContentResourcePack(key: 'faithful', name: 'Faithful');

      expect(
        () => MtnMinecraftContentVersion(
          key: 'faithful-fabric',
          content: resourcePack,
          name: 'Faithful',
          version: '1',
          releaseType: MtnMinecraftContentVersionReleaseType.release,
          modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
        ),
        throwsArgumentError,
      );

      expect(
        MtnMinecraftContentVersion(
          key: 'faithful-vanilla',
          content: resourcePack,
          name: 'Faithful',
          version: '1',
          releaseType: MtnMinecraftContentVersionReleaseType.release,
          modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.vanilla],
        ).modLoaders,
        <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.vanilla],
      );
    });
  });

  group('flat relation graph', () {
    test('one version can be embedded by multiple owner versions', () {
      final list = MtnMinecraftContentList();
      final library = MtnMinecraftContentMod(key: 'library', name: 'Shared Library');
      final modA = MtnMinecraftContentMod(key: 'mod-a', name: 'Mod A');
      final modB = MtnMinecraftContentMod(key: 'mod-b', name: 'Mod B');

      final libraryVersion = _modVersion('library-1', library, '1');
      final modAVersion = _modVersion('mod-a-1', modA, '1');
      final modBVersion = _modVersion('mod-b-1', modB, '1');

      list.addContent(library);
      list.addContent(modA);
      list.addContent(modB);
      list.addVersion(libraryVersion);
      list.addVersion(modAVersion);
      list.addVersion(modBVersion);
      list.addRelation(MtnMinecraftContentRelation(source: libraryVersion, owner: modAVersion, type: MtnMinecraftContentRelationType.embedded));
      list.addRelation(MtnMinecraftContentRelation(source: libraryVersion, owner: modBVersion, type: MtnMinecraftContentRelationType.embedded));

      expect(list.contents.length, 3);
      expect(library.versions.length, 1);
      expect(list.relations.length, 2);
      expect(list.relations.where((relation) => identical(relation.source, libraryVersion)).length, 2);
    });
  });

  group('persistence', () {
    test('round trip restores concrete content, versions, dependencies and relations', () {
      final list = MtnMinecraftContentList();
      final fabricApi = MtnMinecraftContentMod(
        key: 'fabric-api',
        name: 'Fabric API',
        providers: <MtnMinecraftContentProviderMetadata>[
          MtnMinecraftContentProviderMetadata(provider: 'modrinth', id: 'P7dR8mSH', metadata: <String, dynamic>{'downloads': 100}),
          MtnMinecraftContentProviderMetadata(provider: 'curseforge', id: '306612', metadata: <String, dynamic>{'downloadCount': 200}),
        ],
      );
      final mod = MtnMinecraftContentMod(key: 'example-mod', name: 'Example Mod');

      final fabric14 = _modVersion('fabric-api-14', fabricApi, '14');
      final fabric15 = MtnMinecraftContentVersion(
        key: 'fabric-api-15',
        content: fabricApi,
        name: 'Fabric API 15',
        version: '15',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric, MtnMinecraftModLoaderType.quilt],
        files: <MtnMinecraftContentFile>[
          MtnMinecraftContentFile(
            fileName: 'fabric-api-15.jar',
            primary: true,
            hashes: <MtnMinecraftContentFileHash>[
              MtnMinecraftContentFileHash(algorithm: 'sha1', value: 'abc123'),
            ],
          ),
        ],
      );
      final modVersion = MtnMinecraftContentVersion(
        key: 'example-mod-2',
        content: mod,
        name: 'Example Mod 2',
        version: '2',
        releaseType: MtnMinecraftContentVersionReleaseType.release,
        modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
        dependencies: <MtnMinecraftContentDependency>[
          MtnMinecraftContentDependency(
            type: MtnMinecraftContentDependencyType.required,
            provider: 'modrinth',
            providerContentId: 'P7dR8mSH',
            content: fabricApi,
            version: fabric15,
          ),
        ],
      );

      list.addContent(fabricApi);
      list.addContent(mod);
      list.addVersion(fabric14);
      list.addVersion(fabric15);
      list.addVersion(modVersion);
      list.addRelation(MtnMinecraftContentRelation(source: fabric14, owner: modVersion, type: MtnMinecraftContentRelationType.embedded));
      fabricApi.version = fabric14;

      final restored = MtnMinecraftContentList.decode(list.encode());
      final restoredFabric = restored.contents.firstWhere((content) => content.key == 'fabric-api');
      final restoredMod = restored.contents.firstWhere((content) => content.key == 'example-mod');
      final restoredModVersion = restoredMod.versions.single;
      final restoredDependency = restoredModVersion.dependencies.single;

      expect(restoredFabric, isA<MtnMinecraftContentMod>());
      expect(restoredFabric.providers.length, 2);
      expect(restoredFabric.version.key, 'fabric-api-14');
      expect(restoredFabric.versions.last.files.single.hashes.single.value, 'abc123');
      expect(restoredDependency.content, same(restoredFabric));
      expect(restoredDependency.version, same(restoredFabric.versions.last));
      expect(restored.relations.single.source, same(restoredFabric.versions.first));
      expect(restored.relations.single.owner, same(restoredModVersion));
    });

    test('rejects duplicate provider content identities', () {
      final list = MtnMinecraftContentList();
      list.addContent(
        MtnMinecraftContentMod(
          key: 'one',
          name: 'One',
          providers: <MtnMinecraftContentProviderMetadata>[
            MtnMinecraftContentProviderMetadata(provider: 'modrinth', id: 'same'),
          ],
        ),
      );

      expect(
        () => list.addContent(
          MtnMinecraftContentMod(
            key: 'two',
            name: 'Two',
            providers: <MtnMinecraftContentProviderMetadata>[
              MtnMinecraftContentProviderMetadata(provider: 'modrinth', id: 'same'),
            ],
          ),
        ),
        throwsStateError,
      );
    });
  });
}

MtnMinecraftContentVersion _modVersion(String key, MtnMinecraftContentMod content, String version) {
  return MtnMinecraftContentVersion(
    key: key,
    content: content,
    name: '${content.name} $version',
    version: version,
    releaseType: MtnMinecraftContentVersionReleaseType.release,
    modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
  );
}
