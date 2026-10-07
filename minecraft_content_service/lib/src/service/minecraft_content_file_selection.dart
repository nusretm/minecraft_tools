import '../model/minecraft_content_models.dart';
import 'minecraft_content_dependency_desired_state.dart';
import 'minecraft_content_dependency_reconciliation.dart';

class MtnMinecraftContentFileSelection {
  MtnMinecraftContentFileSelection({
    required this.desired,
    required this.file,
  }) {
    if (!desired.version.files.any((item) => identical(item, file))) throw ArgumentError.value(file, 'file', 'Selected file must belong to the desired version.');
    if (file.available == false) throw ArgumentError.value(file, 'file', 'Unavailable files cannot be selected.');
  }

  final MtnMinecraftContentDependencyDesiredVersion desired;
  final MtnMinecraftContentFile file;
}

abstract class MtnMinecraftContentFileSelectionIssue {
  const MtnMinecraftContentFileSelectionIssue({
    required this.desired,
  });

  final MtnMinecraftContentDependencyDesiredVersion desired;
}

class MtnMinecraftContentFileSelectionIssueNoFiles extends MtnMinecraftContentFileSelectionIssue {
  MtnMinecraftContentFileSelectionIssueNoFiles({
    required super.desired,
  }) {
    if (desired.version.files.isNotEmpty) throw ArgumentError.value(desired, 'desired', 'No-files issue requires a desired version with no files.');
  }
}

class MtnMinecraftContentFileSelectionIssueAmbiguous extends MtnMinecraftContentFileSelectionIssue {
  MtnMinecraftContentFileSelectionIssueAmbiguous({
    required super.desired,
    required List<MtnMinecraftContentFile> candidates,
  }) : candidates = List<MtnMinecraftContentFile>.unmodifiable(candidates) {
    if (this.candidates.length < 2) throw ArgumentError.value(this.candidates, 'candidates', 'Ambiguous selection requires at least two candidate files.');
    if (this.candidates.length != desired.version.files.length || !this.candidates.asMap().entries.every((entry) => identical(entry.value, desired.version.files[entry.key]))) {
      throw ArgumentError.value(this.candidates, 'candidates', 'Ambiguous candidates must exactly match the desired version file list.');
    }

    final primaryCount = this.candidates.where((file) => file.primary).length;
    if (primaryCount == 1) throw ArgumentError.value(this.candidates, 'candidates', 'Exactly one primary file is not ambiguous.');
  }

  final List<MtnMinecraftContentFile> candidates;
}

class MtnMinecraftContentFileSelectionIssueUnavailable extends MtnMinecraftContentFileSelectionIssue {
  MtnMinecraftContentFileSelectionIssueUnavailable({
    required super.desired,
    required this.file,
  }) {
    if (!desired.version.files.any((item) => identical(item, file))) throw ArgumentError.value(file, 'file', 'Unavailable file must belong to the desired version.');
    if (file.available != false) throw ArgumentError.value(file, 'file', 'Unavailable issue requires available == false.');
  }

  final MtnMinecraftContentFile file;
}

class MtnMinecraftContentFileSelectionPlan {
  MtnMinecraftContentFileSelectionPlan({
    required this.reconciliation,
    required List<MtnMinecraftContentFileSelection> selections,
    required List<MtnMinecraftContentFileSelectionIssue> issues,
  }) : selections = List<MtnMinecraftContentFileSelection>.unmodifiable(selections),
       issues = List<MtnMinecraftContentFileSelectionIssue>.unmodifiable(issues) {
    final targetByKey = <String, MtnMinecraftContentDependencyDesiredVersion>{
      for (final item in reconciliation.installs) item.version.key: item,
      for (final item in reconciliation.replacements) item.desired.version.key: item.desired,
    };

    final representedKeys = <String>{};

    for (final selection in this.selections) {
      final canonical = targetByKey[selection.desired.version.key];
      if (!identical(canonical, selection.desired)) throw ArgumentError.value(selection, 'selections', 'Selections must reference canonical install/replace desired entries.');
      if (!representedKeys.add(selection.desired.version.key)) throw ArgumentError.value(selection, 'selections', 'A file-selection target cannot be represented more than once.');
    }

    for (final issue in this.issues) {
      final canonical = targetByKey[issue.desired.version.key];
      if (!identical(canonical, issue.desired)) throw ArgumentError.value(issue, 'issues', 'Issues must reference canonical install/replace desired entries.');
      if (!representedKeys.add(issue.desired.version.key)) throw ArgumentError.value(issue, 'issues', 'A file-selection target cannot be represented more than once.');
    }

    if (representedKeys.length != targetByKey.length || !representedKeys.every(targetByKey.containsKey)) throw ArgumentError('File-selection results must cover every install/replace target exactly once.');
  }

  final MtnMinecraftContentDependencyReconciliationPlan reconciliation;
  final List<MtnMinecraftContentFileSelection> selections;
  final List<MtnMinecraftContentFileSelectionIssue> issues;

  bool get selectable => issues.isEmpty;
}
