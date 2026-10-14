import 'dart:io';

import 'package:minecraft_content_service/minecraft_content_service.dart';

/// Live CP-10 metadata-only smoke. No downloads and no installer execution.
/// Run: dart run example/content_package_dependency_lock_rebuild.dart 6qAuTtLR 1.21.11 0.16.14
Future<void> main(List<String> args) async {
  if (args.length != 3) {
    stderr.writeln('Usage: dart run example/content_package_dependency_lock_rebuild.dart EXACT_VERSION_ID MINECRAFT_VERSION LOADER_VERSION');
    exitCode = 64;
    return;
  }
  final provider = MtnMinecraftContentProviderModrinth(
    userAgent: 'nusretm/minecraft_tools CP-10 (https://github.com/nusretm/minecraft_tools)',
  );
  final service = MtnMinecraftContentService(providers: <MtnMinecraftContentProvider>[provider]);
  try {
    final selected = await service.getVersion(provider.name, args[0]);
    final now = DateTime.now().toUtc();
    final package = MtnMinecraftContentPackage(
      id: 'cp10-modrinth-smoke', title: 'Dependency Lock Smoke',
      minecraftVersion: args[1], modLoader: MtnMinecraftModLoaderType.fabric,
      loaderVersion: args[2], ramMiB: 4096, ownerName: 'Local user',
      createdAt: now, updatedAt: now, items: const <MtnMinecraftContentPackageItem>[],
    );
    if (!package.add(selected)) throw StateError('Provider-selected root is incompatible with package version/loader.');

    final desired = await package.resolveDependencies(service);
    if (!desired.installable) {
      stdout.writeln('UNRESOLVED: ${desired.versions.length} versions; ${desired.conflicts.length} conflicts.');
      for (final plan in desired.plans) {
        stdout.writeln('root=${plan.root.key} unresolved=${plan.unresolvedInstallEdges.length} conflicts=${plan.conflicts.length}');
      }
      exitCode = 1;
      return;
    }

    // Explicit deterministic file selection: one available file, or exactly one
    // provider-declared primary. Never choose an arbitrary artifact.
    final selections = <String, MtnMinecraftContentFile>{};
    for (final version in desired.installVersions) {
      final available = version.files.where((file) => file.available != false).toList(growable: false);
      final primary = available.where((file) => file.primary).toList(growable: false);
      final file = available.length == 1 ? available.single : primary.length == 1 ? primary.single : null;
      if (file == null) throw StateError('Ambiguous available file for version ${version.key}; choose one explicitly.');
      selections[version.key] = file;
    }

    if (!package.rebuildLock(desired, selectedFilesByVersionKey: selections)) {
      throw StateError('Package rejected resolved dependency state.');
    }
    final portable = package.encode();
    final reopened = MtnMinecraftContentPackage.decode(portable);
    if (reopened.lock == null || reopened.lock!.versions.length != desired.installVersions.length) {
      throw StateError('Exact lock did not survive portable round-trip.');
    }
    stdout.writeln('CP-10 PASS version=${selected.version} roots=${package.directItems.length} items=${package.items.length}');
    stdout.writeln('exactLockVersions=${reopened.lock!.versions.length} dependencyEdges=${reopened.lock!.edges.length} portableBytes=${portable.length}');
  } finally {
    provider.close();
  }
}
