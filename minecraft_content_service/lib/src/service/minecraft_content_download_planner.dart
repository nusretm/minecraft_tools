import '../provider/minecraft_content_provider_list.dart';
import 'minecraft_content_download_plan.dart';
import 'minecraft_content_file_selection.dart';

class MtnMinecraftContentDownloadPlanner {
  const MtnMinecraftContentDownloadPlanner(this.providers);

  final MtnMinecraftContentProviderList providers;

  Future<MtnMinecraftContentDownloadPlan> plan(
    MtnMinecraftContentFileSelectionPlan selection,
  ) async {
    if (!selection.selectable) throw StateError('Download planning requires a selectable file-selection plan.');

    final items = <MtnMinecraftContentDownloadItem>[];
    final issues = <MtnMinecraftContentDownloadIssue>[];

    for (final selected in selection.selections) {
      final directUrl = selected.file.downloadUrl;
      if (directUrl != null) {
        final uri = Uri.tryParse(directUrl);
        if (uri == null || !_usableDownloadUri(uri)) {
          issues.add(
            MtnMinecraftContentDownloadIssueInvalidUrl(
              selection: selected,
              value: directUrl,
            ),
          );
        } else {
          items.add(
            MtnMinecraftContentDownloadItem(
              selection: selected,
              url: uri,
            ),
          );
        }
        continue;
      }

      final providerNames = <String>[];
      for (final metadata in selected.file.providers) {
        final name = metadata.provider;
        if (name.isEmpty || providerNames.contains(name)) continue;
        providerNames.add(name);
      }

      if (providerNames.isEmpty) {
        issues.add(
          MtnMinecraftContentDownloadIssueProviderMissing(
            selection: selected,
          ),
        );
        continue;
      }

      if (providerNames.length > 1) {
        issues.add(
          MtnMinecraftContentDownloadIssueProviderAmbiguous(
            selection: selected,
            providers: providerNames,
          ),
        );
        continue;
      }

      final providerName = providerNames.single;
      final provider = providers.getFromName(providerName);
      if (provider == null) {
        issues.add(
          MtnMinecraftContentDownloadIssueProviderNotRegistered(
            selection: selected,
            providerName: providerName,
          ),
        );
        continue;
      }

      if (!provider.ready) {
        issues.add(
          MtnMinecraftContentDownloadIssueProviderNotReady(
            selection: selected,
            providerName: providerName,
          ),
        );
        continue;
      }

      try {
        final uri = await provider.resolveDownloadSource(selected.desired.version, selected.file);
        if (uri == null) {
          issues.add(
            MtnMinecraftContentDownloadIssueSourceUnavailable(
              selection: selected,
              providerName: providerName,
            ),
          );
          continue;
        }

        if (!_usableDownloadUri(uri)) {
          issues.add(
            MtnMinecraftContentDownloadIssueInvalidUrl(
              selection: selected,
              value: uri.toString(),
              providerName: providerName,
            ),
          );
          continue;
        }

        items.add(
          MtnMinecraftContentDownloadItem(
            selection: selected,
            url: uri,
          ),
        );
      } catch (error) {
        issues.add(
          MtnMinecraftContentDownloadIssueSourceResolutionFailed(
            selection: selected,
            providerName: providerName,
            error: error,
          ),
        );
      }
    }

    return MtnMinecraftContentDownloadPlan(
      selection: selection,
      items: items,
      issues: issues,
    );
  }
}

bool _usableDownloadUri(Uri uri) {
  if (!uri.hasScheme || uri.host.isEmpty) return false;
  return uri.scheme == 'http' || uri.scheme == 'https';
}
