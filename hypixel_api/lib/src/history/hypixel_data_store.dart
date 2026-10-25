import 'dart:convert';
import 'dart:io';

import '../storage/hypixel_file_operation_queue.dart';

class HypixelDataStore {
  HypixelDataStore({String? folder})
      : rootDirectory = Directory(
          folder ??
              '${Directory.systemTemp.path}${Platform.pathSeparator}hypixel_api',
        ),
        cacheDirectory = Directory(
          '${folder ?? '${Directory.systemTemp.path}${Platform.pathSeparator}hypixel_api'}${Platform.pathSeparator}cache${Platform.pathSeparator}requests',
        ),
        historyDirectory = Directory(
          '${folder ?? '${Directory.systemTemp.path}${Platform.pathSeparator}hypixel_api'}${Platform.pathSeparator}history',
        );

  final Directory rootDirectory;
  final Directory cacheDirectory;
  final Directory historyDirectory;

  File historyFile(String name) => File(
        '${historyDirectory.path}${Platform.pathSeparator}$name.json',
      );

  /// Serializes reads with writes of the same history identity. The public
  /// methods and updateHistory all use the same path-scoped operation queue.
  Future<Map<String, dynamic>?> readHistory(String name) {
    final file = historyFile(name);
    return HypixelFileOperationQueue.run<Map<String, dynamic>?>(
      file.path, () => _readHistoryFile(file),
    );
  }

  Future<void> writeHistory(String name, Map<String, dynamic> value) {
    final file = historyFile(name);
    return HypixelFileOperationQueue.run<void>(
      file.path, () => _writeHistoryFile(file, value),
    );
  }

  /// Atomically performs one read-modify-write for this history identity
  /// within the isolate. The synchronous callback cannot await another
  /// operation on this file or observe an intermediate version.
  ///
  /// Direct writeHistory remains a replace operation (last writer wins);
  /// observers that merge records must use updateHistory instead.
  Future<void> updateHistory(
    String name,
    Map<String, dynamic> Function(Map<String, dynamic>? previous) update,
  ) {
    final file = historyFile(name);
    return HypixelFileOperationQueue.run<void>(file.path, () async {
      final previous = await _readHistoryFile(file);
      final value = update(previous);
      await _writeHistoryFile(file, value);
    });
  }

  Future<Map<String, dynamic>?> _readHistoryFile(File file) async {
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map<String, dynamic>
          ? decoded
          : Map<String, dynamic>.from(decoded as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeHistoryFile(File file, Map<String, dynamic> value) async {
    await historyDirectory.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(value), flush: true);
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }
}
