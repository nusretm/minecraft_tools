import '../model/minecraft_content_models.dart';
import 'minecraft_content_dependency_desired_state.dart';
import 'minecraft_content_dependency_reconciliation.dart';
import 'minecraft_content_file_selection.dart';

class MtnMinecraftContentFileSelector {
  const MtnMinecraftContentFileSelector();

  MtnMinecraftContentFileSelectionPlan select(
    MtnMinecraftContentDependencyReconciliationPlan reconciliation,
  ) {
    final targetByKey = <String, MtnMinecraftContentDependencyDesiredVersion>{
      for (final item in reconciliation.installs) item.version.key: item,
      for (final item in reconciliation.replacements) item.desired.version.key: item.desired,
    };

    final selections = <MtnMinecraftContentFileSelection>[];
    final issues = <MtnMinecraftContentFileSelectionIssue>[];

    for (final desired in reconciliation.desired.versions) {
      if (!targetByKey.containsKey(desired.version.key)) continue;

      final files = desired.version.files;
      if (files.isEmpty) {
        issues.add(MtnMinecraftContentFileSelectionIssueNoFiles(desired: desired));
        continue;
      }

      MtnMinecraftContentFile? selected;
      if (files.length == 1) {
        selected = files.single;
      } else {
        final primaryFiles = files.where((file) => file.primary).toList(growable: false);
        if (primaryFiles.length != 1) {
          issues.add(
            MtnMinecraftContentFileSelectionIssueAmbiguous(
              desired: desired,
              candidates: files,
            ),
          );
          continue;
        }
        selected = primaryFiles.single;
      }

      if (selected.available == false) {
        issues.add(
          MtnMinecraftContentFileSelectionIssueUnavailable(
            desired: desired,
            file: selected,
          ),
        );
        continue;
      }

      selections.add(
        MtnMinecraftContentFileSelection(
          desired: desired,
          file: selected,
        ),
      );
    }

    return MtnMinecraftContentFileSelectionPlan(
      reconciliation: reconciliation,
      selections: selections,
      issues: issues,
    );
  }
}
