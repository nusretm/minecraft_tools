import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:minecraft_content_service/minecraft_content_service.dart';

/// Live CP-09 smoke:
/// dart run example/content_package_add_modrinth.dart 1.21.11 0.16.14
///
/// Searches Modrinth Fabric API, selects the latest compatible published
/// version, adds that exact version, and reopens the AES-GCM local draft.
/// No mod is downloaded/installed and an unlocked draft cannot be published.
Future<void> main(List<String> args) async {
  final minecraftVersion = args.isNotEmpty ? args[0] : '1.21.11';
  final loaderVersion = args.length > 1 ? args[1] : '0.16.14';
  final provider = MtnMinecraftContentProviderModrinth(
    userAgent: 'nusretm/minecraft_tools CP-09 (https://github.com/nusretm/minecraft_tools)',
  );
  final service = MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[provider]);
  final root = await Directory.systemTemp.createTemp('mtn-package-add-');
  try {
    final results = await service.search(provider.name, MtnMinecraftContentSearchRequest(
      query: 'fabric api', types: <MtnMinecraftContentType>[MtnMinecraftContentType.mod],
      gameVersions: <String>[minecraftVersion], modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
    ));
    final fabricApi = results.contents.where((item) => item.name.toLowerCase() == 'fabric api').firstOrNull;
    if (fabricApi == null) throw StateError('Fabric API not found on Modrinth.');

    final versions = await service.getVersions(provider.name, fabricApi, MtnMinecraftContentVersionListRequest(
      gameVersions: <String>[minecraftVersion],
      modLoaders: <MtnMinecraftModLoaderType>[MtnMinecraftModLoaderType.fabric],
    ));
    final compatible = versions.versions.where((value) =>
        value.gameVersions.contains(minecraftVersion) &&
        value.modLoaders.contains(MtnMinecraftModLoaderType.fabric) &&
        value.publishedAt != null).toList(growable: false)
      ..sort((a, b) => b.publishedAt!.compareTo(a.publishedAt!));
    if (compatible.isEmpty) throw StateError('No dated compatible Fabric API version found.');

    final now = DateTime.now().toUtc();
    final package = MtnMinecraftContentPackage(
      id: 'fabric-api-example', title: 'Fabric API draft',
      minecraftVersion: minecraftVersion, modLoader: MtnMinecraftModLoaderType.fabric,
      loaderVersion: loaderVersion, ramMiB: 4096, ownerName: 'Local user',
      createdAt: now, updatedAt: now,
      items: const <MtnMinecraftContentPackageItem>[],
    );
    final selected = compatible.first;
    if (!package.add(selected)) throw StateError('Selected compatible provider version was not added.');
    final selectedItem = package.items.single;
    if (!selectedItem.effectiveEnabled || selectedItem.version?.version != selected.version) {
      throw StateError('Added item lost its selected version.');
    }

    final local = MtnMinecraftContentPackageRecord(package: package, source: MtnMinecraftContentPackageSource.local);
    final storage = MtnMinecraftContentPackageRecordStorage(directory: Directory('${root.path}${Platform.pathSeparator}records'));
    final random = Random.secure();
    final key = Uint8List.fromList(List<int>.generate(32, (_) => random.nextInt(256)));
    const recordId = '06d12a88-c7af-4de5-aed4-4828451d05b7';
    await storage.save(recordId, local, key: key, keyId: 'smoke-only');
    final reopened = await storage.load(recordId, key: key);
    final item = reopened?.package.items.single;
    if (item?.selectedVersionId != selected.providers.firstWhere((entry) => entry.provider == provider.name).id) {
      throw StateError('Encrypted local draft lost the selected Modrinth version ID.');
    }

    stdout.writeln('CP-09 PASS provider=modrinth project=${selectedItem.projectId} version=${selected.version}');
    stdout.writeln('type=${selectedItem.type.name} effectiveEnabled=${selectedItem.effectiveEnabled} savedVersionId=${item!.selectedVersionId}');
    stdout.writeln('Draft lock=${reopened!.package.lock}; portable publish requires full dependency/artefact lock.');
  } finally {
    provider.close();
    if (await root.exists()) await root.delete(recursive: true);
  }
}
