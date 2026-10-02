import 'dart:convert';
import 'dart:io';

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

  Future<Map<String, dynamic>?> readHistory(String name) async {
    final file = historyFile(name);
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

  Future<void> writeHistory(String name, Map<String, dynamic> value) async {
    await historyDirectory.create(recursive: true);
    final file = historyFile(name);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(value), flush: true);
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }
}
