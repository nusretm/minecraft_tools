import '../model/minecraft_content_models.dart';
import '../service/minecraft_content_dependency_desired_state.dart';
import 'minecraft_content_package.dart';
import 'minecraft_content_package_item.dart';
import 'minecraft_content_package_lock.dart';

/// Creates a portable exact-lock snapshot from the existing multi-root planner.
///
/// This class does not resolve dependencies, choose "latest" versions, pick
/// arbitrary files, inspect installed state or perform network/file I/O.
/// Each desired version needs an explicitly selected file, including retains:
/// the existing file-selection planner covers only install/replace targets.
class MtnMinecraftContentPackageBuilder {
  const MtnMinecraftContentPackageBuilder();

  MtnMinecraftContentPackage build({
    required String id,
    required String title,
    required String minecraftVersion,
    required MtnMinecraftModLoaderType modLoader,
    required int ramMiB,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String ownerName,
    String? loaderVersion,
    String? serverAddress,
    required MtnMinecraftContentDependencyDesiredState desired,
    required Map<String, MtnMinecraftContentFile> selectedFilesByVersionKey,
    String? description,
    String? iconUrl,
    String? logoImageFileName,
    MtnMinecraftContentPackageLogoImageMode logoImageMode = MtnMinecraftContentPackageLogoImageMode.fit,
    int revision = 1,
    MtnMinecraftContentPackageMutationPolicy mutationPolicy = MtnMinecraftContentPackageMutationPolicy.none,
    Map<String, List<MtnMinecraftContentItemPermission>> permissionsByItemKey = const <String, List<MtnMinecraftContentItemPermission>>{},
  }) {
    if (!desired.installable) throw StateError('Cannot publish unresolved or conflicting dependency install plans.');
    if (desired.versions.isEmpty || desired.directVersions.isEmpty) throw StateError('A published package needs at least one direct version.');
    final versionsByKey = <String, MtnMinecraftContentVersion>{
      for (final entry in desired.versions) entry.version.key: entry.version,
    };
    final selectedKeys = selectedFilesByVersionKey.keys.toSet();
    if (selectedKeys.length != versionsByKey.length || !selectedKeys.containsAll(versionsByKey.keys)) {
      throw ArgumentError.value(selectedFilesByVersionKey.keys.toList(), 'selectedFilesByVersionKey', 'Every desired version, including retains, needs exactly one explicit file choice.');
    }

    final directKeys = desired.directVersions.map((version) => version.key).toSet();
    final items = <MtnMinecraftContentPackageItem>[];
    final locked = <MtnMinecraftContentPackageLockedVersion>[];
    final itemKeysByVersion = <String, String>{};
    final versionKeysByItem = <String, String>{};

    for (final version in versionsByKey.values) {
      final candidates = version.providers.where((metadata) =>
          metadata.id != null && metadata.id!.isNotEmpty &&
          version.content.providers.any((owner) => owner.provider == metadata.provider && owner.id != null && owner.id!.isNotEmpty)).toList(growable: false);
      if (candidates.length != 1) throw StateError('Version ${version.key} must have exactly one canonical provider that also owns its content.');
      final identity = candidates.single;
      final projectId = version.content.providers.firstWhere((metadata) => metadata.provider == identity.provider).id!;
      final itemKey = '${identity.provider}:$projectId';
      if (versionKeysByItem.containsKey(itemKey)) throw StateError('Package contains incompatible or duplicate versions for item $itemKey.');
      versionKeysByItem[itemKey] = version.key;
      itemKeysByVersion[version.key] = itemKey;

      final isDirect = directKeys.contains(version.key);
      final permissions = permissionsByItemKey[itemKey] ?? const <MtnMinecraftContentItemPermission>[];
      items.add(MtnMinecraftContentPackageItem(
        provider: identity.provider,
        projectId: projectId,
        type: version.content.type,
        title: version.content.name,
        description: version.content.summary ?? version.content.description,
        iconUrl: version.content.icon?.url,
        direct: isDirect,
        permissions: permissions,
      ));

      final file = selectedFilesByVersionKey[version.key]!;
      if (!version.files.any((candidate) => identical(candidate, file)) || file.available == false) {
        throw ArgumentError.value(file, 'selectedFilesByVersionKey', 'Selected file must be an available member of exact version ${version.key}.');
      }
      final fileIds = file.providers.where((metadata) => metadata.provider == identity.provider && metadata.id != null && metadata.id!.isNotEmpty).toList(growable: false);
      if (fileIds.length > 1) throw StateError('Ambiguous file ID for ${version.key}.');
      final fileId = fileIds.isEmpty ? null : fileIds.single.id;
      const hashLengths = <String, int>{'sha512': 128, 'sha256': 64, 'sha1': 40, 'md5': 32};
      MtnMinecraftContentFileHash? chosenHash;
      String? chosenAlgorithm;
      for (final entry in hashLengths.entries) {
        for (final hash in file.hashes) {
          final normalized = hash.algorithm.toLowerCase().replaceAll('-', '');
          if (normalized != entry.key) continue;
          if (hash.value.length == entry.value && RegExp(r'^[a-fA-F0-9]+$').hasMatch(hash.value)) {
            chosenHash = hash;
            chosenAlgorithm = normalized;
            break;
          }
        }
        if (chosenHash != null) break;
      }
      if (fileId == null && chosenHash == null) throw StateError('Selected file ${file.fileName} has no portable provider file ID or supported integrity hash.');

      locked.add(MtnMinecraftContentPackageLockedVersion(
        itemKey: itemKey,
        versionId: identity.id!,
        fileName: file.fileName,
        fileId: fileId,
        hashAlgorithm: chosenAlgorithm,
        hashValue: chosenHash?.value,
        size: file.size,
      ));
    }

    for (final key in permissionsByItemKey.keys) {
      if (!versionKeysByItem.containsKey(key)) throw ArgumentError.value(key, 'permissionsByItemKey', 'Permission references a missing package item.');
    }

    final edges = <MtnMinecraftContentPackageLockedEdge>[];
    final seenEdges = <(String, String, MtnMinecraftContentDependencyType)>{};
    for (final plan in desired.plans) {
      for (final edge in plan.installEdges) {
        final target = edge.target;
        if (target == null) throw StateError('Install plan contains a missing dependency target.');
        final sourceKey = itemKeysByVersion[edge.source.key];
        final targetKey = itemKeysByVersion[target.key];
        if (sourceKey == null || targetKey == null) throw StateError('Install plan references a version outside the desired package.');
        final type = edge.dependency.type;
        final identity = (sourceKey, targetKey, type);
        if (seenEdges.add(identity)) {
          edges.add(MtnMinecraftContentPackageLockedEdge(sourceKey: sourceKey, targetKey: targetKey, type: type));
        }
      }
    }

    return MtnMinecraftContentPackage(
      id: id,
      title: title,
      description: description,
      iconUrl: iconUrl,
      logoImageFileName: logoImageFileName,
      logoImageMode: logoImageMode,
      minecraftVersion: minecraftVersion,
      modLoader: modLoader,
      loaderVersion: loaderVersion,
      ramMiB: ramMiB,
      serverAddress: serverAddress,
      createdAt: createdAt,
      updatedAt: updatedAt,
      ownerName: ownerName,
      revision: revision,
      mutationPolicy: mutationPolicy,
      items: items,
      lock: MtnMinecraftContentPackageLock(versions: locked, edges: edges),
    );
  }
}
