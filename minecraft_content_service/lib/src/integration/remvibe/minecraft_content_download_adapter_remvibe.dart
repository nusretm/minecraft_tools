import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:remvibe_download_service/remvibe_download_service.dart';

import '../../service/minecraft_content_download_plan.dart';
import '../../service/minecraft_content_materialization_plan.dart';
import 'minecraft_content_download_integrity_remvibe.dart';

class MtnMinecraftContentDownloadAdapterRemVibeItem {
  const MtnMinecraftContentDownloadAdapterRemVibeItem({
    required this.target,
    required this.integrity,
    required this.item,
  });

  final MtnMinecraftContentMaterializationTarget target;
  final MtnMinecraftContentDownloadIntegrityRemVibe? integrity;
  final RemVibeDownloadItem item;
}

class MtnMinecraftContentDownloadAdapterRemVibeBatch {
  MtnMinecraftContentDownloadAdapterRemVibeBatch({
    required this.plan,
    required this.stagingRoot,
    required this.job,
    required List<MtnMinecraftContentDownloadAdapterRemVibeItem> items,
  }) : items = List<MtnMinecraftContentDownloadAdapterRemVibeItem>.unmodifiable(items);

  final MtnMinecraftContentMaterializationPlan plan;
  final Directory stagingRoot;
  final RemVibeDownloadJob job;
  final List<MtnMinecraftContentDownloadAdapterRemVibeItem> items;
}

class MtnMinecraftContentDownloadAdapterRemVibe {
  const MtnMinecraftContentDownloadAdapterRemVibe();

  MtnMinecraftContentDownloadAdapterRemVibeBatch createBatch({
    required MtnMinecraftContentMaterializationPlan plan,
    required Directory stagingRoot,
    required String key,
    required String title,
    int maxConcurrentItems = 5,
    int maxErrorCount = 3,
    RemVibeDownloadJobStatusCallback? onStatus,
  }) {
    if (plan.download.items.isEmpty) throw ArgumentError.value(plan, 'plan', 'A RemVibe download batch requires at least one download item.');

    final targetByDownload = <MtnMinecraftContentDownloadItem, MtnMinecraftContentMaterializationTarget>{};

    for (final action in plan.installs) {
      _registerTarget(targetByDownload, action.target);
    }
    for (final action in plan.replacements) {
      _registerTarget(targetByDownload, action.target);
    }

    final items = <MtnMinecraftContentDownloadAdapterRemVibeItem>[];
    for (final download in plan.download.items) {
      final target = targetByDownload[download];
      if (target == null) throw StateError('Materialization plan does not expose a target for download ${download.selection.desired.version.key}.');

      final segments = target.relativePath.split('/');
      final filename = segments.last;
      final directorySegments = segments.length == 1 ? const <String>[] : segments.sublist(0, segments.length - 1);
      final directory = Directory(
        directorySegments.isEmpty ? stagingRoot.path : p.joinAll(<String>[stagingRoot.path, ...directorySegments]),
      );

      final integrity = MtnMinecraftContentDownloadIntegrityRemVibe.fromFile(
        target.artifact.file,
      );
      final item = RemVibeDownloadItem(
        url: download.url,
        directory: directory,
        filename: filename,
        size: target.artifact.file.size,
        validator: integrity?.validate,
      );

      items.add(
        MtnMinecraftContentDownloadAdapterRemVibeItem(
          target: target,
          integrity: integrity,
          item: item,
        ),
      );
    }

    final job = RemVibeDownloadJob(
      key: key,
      title: title,
      items: items.map((item) => item.item).toList(growable: false),
      onStatus: onStatus,
      maxConcurrentItems: maxConcurrentItems,
      maxErrorCount: maxErrorCount,
    );

    return MtnMinecraftContentDownloadAdapterRemVibeBatch(
      plan: plan,
      stagingRoot: stagingRoot,
      job: job,
      items: items,
    );
  }

  void _registerTarget(
    Map<MtnMinecraftContentDownloadItem, MtnMinecraftContentMaterializationTarget> targets,
    MtnMinecraftContentMaterializationTarget target,
  ) {
    if (targets.containsKey(target.download)) throw StateError('A canonical content download item cannot map to more than one materialization target.');
    targets[target.download] = target;
  }
}
