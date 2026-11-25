import '../model/crash_report.dart';

final class MtnMinecraftCrashExceptionParser {
  const MtnMinecraftCrashExceptionParser();

  static final RegExp _header = RegExp(r'^\s*(?:(Caused by:|Suppressed:)\s*|Exception in thread "[^"]+"\s+)?((?:[A-Za-z_$][\w$]*\.)*[A-Za-z_$][\w$]*(?:Exception|Error|Throwable)|Exception|Error|Throwable)(?::\s*(.*))?\s*$');
  static final RegExp _frame = RegExp(r'^\s*at\s+([^\s(]+)\(([^)]*)\)(?:\s+.*)?$');

  List<MtnMinecraftCrashException> parse(List<String> lines) {
    final List<MtnMinecraftCrashException> result = [];
    String? type;
    int number = 0;
    MtnMinecraftCrashExceptionRelation relation = MtnMinecraftCrashExceptionRelation.root;
    MtnMinecraftCrashExceptionRelation? pendingRelation;
    final List<String> message = [];
    final List<MtnMinecraftCrashStackFrame> frames = [];
    void finish() {
      final String? current = type;
      if (current == null) return;
      result.add(MtnMinecraftCrashException(type: current, message: message.join('\n'), lineNumber: number,
        relation: relation, frames: frames));
      type = null;
      message.clear();
      frames.clear();
    }
    for (int i = 0; i < lines.length; i++) {
      final String line = lines[i];
      final String trimmed = line.trim();
      if (trimmed == 'Caused by:' || trimmed == 'Suppressed:') {
        finish();
        pendingRelation = trimmed == 'Caused by:' ? MtnMinecraftCrashExceptionRelation.causedBy : MtnMinecraftCrashExceptionRelation.suppressed;
        continue;
      }
      final RegExpMatch? header = _header.firstMatch(trimmed);
      if (header != null) {
        finish();
        type = header.group(2)!;
        number = i + 1;
        relation = header.group(1) == 'Caused by:' ? MtnMinecraftCrashExceptionRelation.causedBy
            : header.group(1) == 'Suppressed:' ? MtnMinecraftCrashExceptionRelation.suppressed
            : pendingRelation ?? MtnMinecraftCrashExceptionRelation.root;
        pendingRelation = null;
        if (header.group(3) != null) message.add(header.group(3)!);
        continue;
      }
      if (trimmed.isEmpty) continue;
      pendingRelation = null;
      if (trimmed.startsWith('-- ') || trimmed.startsWith('---- ') || trimmed == 'Stacktrace:' || trimmed == 'Fabric Mods:') {
        finish();
        continue;
      }
      if (type == null) continue;
      final RegExpMatch? frame = _frame.firstMatch(line);
      if (frame != null) {
        frames.add(MtnMinecraftCrashStackFrame(symbol: frame.group(1)!, location: frame.group(2)!, lineNumber: i + 1));
      } else if (frames.isEmpty && !trimmed.startsWith('... ')) {
        message.add(trimmed);
      }
    }
    finish();
    return result;
  }
}
