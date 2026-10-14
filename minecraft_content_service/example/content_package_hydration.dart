import 'dart:io';

import 'package:minecraft_content_service/minecraft_content_service.dart';

/// Live metadata-only round-trip smoke test for one exact Modrinth version.
///
/// Run: `dart run example/content_package_hydration.dart PROJECT_ID VERSION_ID MINECRAFT_VERSION`
///
/// No download, installation, revision change, or "latest" version selection.
Future<void> main(List<String> args) async {
  if ((args.length != 3 && args.length != 4) || args.any((value) => value.trim().isEmpty)) {
    stderr.writeln('Usage: dart run example/content_package_hydration.dart PROJECT_ID EXACT_VERSION_ID MINECRAFT_VERSION [LOADER_VERSION]');
    exitCode = 64;
    return;
  }

  final projectId = args[0];
  final versionId = args[1];
  final minecraftVersion = args[2];
  final loaderVersion = args.length == 4 ? args[3] : null;
  final provider = MtnMinecraftContentProviderModrinth(userAgent: 'MinecraftTools-ContentPackageHydration/1.0');
  final service = MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[provider]);

  try {
    final providerVersion = await service.getVersion(provider.name, versionId);
    final providerProjectId = providerVersion.content.providers.where((metadata) => metadata.provider == provider.name).map((metadata) => metadata.id).firstOrNull;
    if (providerProjectId != projectId) throw StateError('Version $versionId belongs to project $providerProjectId, not $projectId.');

    final availableFiles = providerVersion.files.where((file) => file.available != false).toList(growable: false);
    if (availableFiles.isEmpty) throw StateError('The selected version contains no available files.');
    final primary = availableFiles.where((file) => file.primary).toList(growable: false);
    final selected = availableFiles.length == 1 ? availableFiles.single : primary.length == 1 ? primary.single : (throw StateError('Ambiguous files; choose a version with one primary file.'));
    final hashes = selected.hashes.where((hash) => const <String>{'md5', 'sha1', 'sha256', 'sha512'}.contains(hash.algorithm)).toList(growable: false);
    final selectedHash = hashes.isEmpty ? null : hashes.first;
    final fileIds = selected.providers.where((metadata) => metadata.provider == provider.name && metadata.id != null).map((metadata) => metadata.id!).toList(growable: false);
    final fileId = fileIds.isEmpty ? null : fileIds.single;
    if (selectedHash == null && fileId == null) throw StateError('Selected file has no portable checksum or provider file ID.');

    final item = MtnMinecraftContentPackageItem(
      provider: provider.name,
      projectId: projectId,
      type: providerVersion.content.type,
      title: providerVersion.content.name,
      direct: true,
      permissions: MtnMinecraftContentItemPermission.values,
    );
    final locked = MtnMinecraftContentPackageLockedVersion(
      itemKey: item.key,
      versionId: versionId,
      fileName: selected.fileName,
      fileId: fileId,
      hashAlgorithm: selectedHash?.algorithm,
      hashValue: selectedHash?.value,
      size: selected.size,
    );
    final selectedLoader = providerVersion.modLoaders.first;
    if (selectedLoader != MtnMinecraftModLoaderType.vanilla && loaderVersion == null) {
      throw StateError('Provide the exact Minecraft loader build as a fourth argument for a modded package.');
    }
    if (selectedLoader == MtnMinecraftModLoaderType.vanilla && loaderVersion != null) {
      throw StateError('Vanilla packages do not accept a loader version.');
    }
    final now = DateTime.now().toUtc();
    final original = MtnMinecraftContentPackage(
      id: 'smoke-$projectId',
      title: '${providerVersion.content.name} exact-version smoke',
      minecraftVersion: minecraftVersion,
      modLoader: selectedLoader,
      loaderVersion: loaderVersion,
      ramMiB: 4096,
      ownerName: 'Metadata Smoke Example',
      createdAt: now,
      updatedAt: now,
      items: <MtnMinecraftContentPackageItem>[item],
      lock: MtnMinecraftContentPackageLock(
        versions: <MtnMinecraftContentPackageLockedVersion>[locked],
        edges: const <MtnMinecraftContentPackageLockedEdge>[],
      ),
    );

    final portable = original.encode();
    final imported = MtnMinecraftContentPackage.decode(portable);
    final cache = MtnMinecraftContentPackageMetadataCache(service);
    await imported.hydrateSequential(service, cache: cache);

    final hydrated = imported.items.single;
    if (hydrated.state != MtnMinecraftContentItemState.loaded) throw StateError('Exact hydration failed: ${hydrated.loadError}');
    if (hydrated.version == null || hydrated.file == null) throw StateError('Exact version/file identity is missing after hydration.');

    stdout.writeln('PASS project=$projectId version=$versionId file=${hydrated.file!.fileName}');
    stdout.writeln('Export bytes=${portable.length}; cache content=${cache.cachedContentCount}, versions=${cache.cachedVersionCount}');
    stdout.writeln('State=${hydrated.state.name}; direct=${hydrated.direct}; effectiveEnabled=${imported.effectiveEnabled(hydrated)}');
  } finally {
    provider.close();
  }
}
