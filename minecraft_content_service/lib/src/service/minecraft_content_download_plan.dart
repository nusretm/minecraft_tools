import 'minecraft_content_file_selection.dart';

class MtnMinecraftContentDownloadItem {
  MtnMinecraftContentDownloadItem({
    required this.selection,
    required this.url,
  }) {
    if (!isUsableUrl(url)) throw ArgumentError.value(url, 'url', 'Download URL must be an absolute HTTP or HTTPS URI.');
  }

  final MtnMinecraftContentFileSelection selection;
  final Uri url;

  static bool isUsableUrl(Uri url) {
    if (!url.hasScheme || url.host.isEmpty) return false;
    return url.scheme == 'http' || url.scheme == 'https';
  }
}

abstract class MtnMinecraftContentDownloadIssue {
  const MtnMinecraftContentDownloadIssue({
    required this.selection,
  });

  final MtnMinecraftContentFileSelection selection;
}

class MtnMinecraftContentDownloadIssueInvalidUrl extends MtnMinecraftContentDownloadIssue {
  MtnMinecraftContentDownloadIssueInvalidUrl({
    required super.selection,
    required this.value,
    this.providerName,
  }) {
    if (providerName != null && providerName!.isEmpty) throw ArgumentError.value(providerName, 'providerName', 'Provider name cannot be empty.');
  }

  final String value;
  final String? providerName;
}

class MtnMinecraftContentDownloadIssueProviderMissing extends MtnMinecraftContentDownloadIssue {
  const MtnMinecraftContentDownloadIssueProviderMissing({
    required super.selection,
  });
}

class MtnMinecraftContentDownloadIssueProviderAmbiguous extends MtnMinecraftContentDownloadIssue {
  MtnMinecraftContentDownloadIssueProviderAmbiguous({
    required super.selection,
    required List<String> providers,
  }) : providers = List<String>.unmodifiable(providers) {
    if (this.providers.length < 2) throw ArgumentError.value(this.providers, 'providers', 'Ambiguous provider identity requires at least two providers.');
    if (this.providers.any((provider) => provider.isEmpty)) throw ArgumentError.value(this.providers, 'providers', 'Provider names cannot be empty.');
    if (this.providers.toSet().length != this.providers.length) throw ArgumentError.value(this.providers, 'providers', 'Ambiguous provider names cannot contain duplicates.');
  }

  final List<String> providers;
}

class MtnMinecraftContentDownloadIssueProviderNotRegistered extends MtnMinecraftContentDownloadIssue {
  MtnMinecraftContentDownloadIssueProviderNotRegistered({
    required super.selection,
    required this.providerName,
  }) {
    if (providerName.isEmpty) throw ArgumentError.value(providerName, 'providerName', 'Provider name cannot be empty.');
  }

  final String providerName;
}

class MtnMinecraftContentDownloadIssueProviderNotReady extends MtnMinecraftContentDownloadIssue {
  MtnMinecraftContentDownloadIssueProviderNotReady({
    required super.selection,
    required this.providerName,
  }) {
    if (providerName.isEmpty) throw ArgumentError.value(providerName, 'providerName', 'Provider name cannot be empty.');
  }

  final String providerName;
}

class MtnMinecraftContentDownloadIssueSourceUnavailable extends MtnMinecraftContentDownloadIssue {
  MtnMinecraftContentDownloadIssueSourceUnavailable({
    required super.selection,
    required this.providerName,
  }) {
    if (providerName.isEmpty) throw ArgumentError.value(providerName, 'providerName', 'Provider name cannot be empty.');
  }

  final String providerName;
}

class MtnMinecraftContentDownloadIssueSourceResolutionFailed extends MtnMinecraftContentDownloadIssue {
  MtnMinecraftContentDownloadIssueSourceResolutionFailed({
    required super.selection,
    required this.providerName,
    required this.error,
  }) {
    if (providerName.isEmpty) throw ArgumentError.value(providerName, 'providerName', 'Provider name cannot be empty.');
  }

  final String providerName;
  final Object error;
}

class MtnMinecraftContentDownloadPlan {
  MtnMinecraftContentDownloadPlan({
    required this.selection,
    required List<MtnMinecraftContentDownloadItem> items,
    required List<MtnMinecraftContentDownloadIssue> issues,
  }) : items = List<MtnMinecraftContentDownloadItem>.unmodifiable(items),
       issues = List<MtnMinecraftContentDownloadIssue>.unmodifiable(issues) {
    if (!selection.selectable) throw ArgumentError.value(selection, 'selection', 'Download planning requires a selectable file-selection plan.');

    final selectionByKey = <String, MtnMinecraftContentFileSelection>{
      for (final item in selection.selections) item.desired.version.key: item,
    };
    final representedKeys = <String>{};

    for (final item in this.items) {
      final canonical = selectionByKey[item.selection.desired.version.key];
      if (!identical(canonical, item.selection)) throw ArgumentError.value(item, 'items', 'Download items must reference canonical file selections.');
      if (!representedKeys.add(item.selection.desired.version.key)) throw ArgumentError.value(item, 'items', 'A download-plan selection cannot be represented more than once.');
    }

    for (final issue in this.issues) {
      final canonical = selectionByKey[issue.selection.desired.version.key];
      if (!identical(canonical, issue.selection)) throw ArgumentError.value(issue, 'issues', 'Download issues must reference canonical file selections.');
      if (!representedKeys.add(issue.selection.desired.version.key)) throw ArgumentError.value(issue, 'issues', 'A download-plan selection cannot be represented more than once.');
    }

    if (representedKeys.length != selectionByKey.length || !representedKeys.every(selectionByKey.containsKey)) throw ArgumentError('Download-plan results must cover every file selection exactly once.');
  }

  final MtnMinecraftContentFileSelectionPlan selection;
  final List<MtnMinecraftContentDownloadItem> items;
  final List<MtnMinecraftContentDownloadIssue> issues;

  bool get downloadable => issues.isEmpty;
}
