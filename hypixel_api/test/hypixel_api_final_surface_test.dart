import 'dart:io';

import 'package:hypixel_api/hypixel_api.dart';
import 'package:test/test.dart';

void main() {
  test('default API instance has no embedded authenticated credential', () {
    final api = HypixelApi();
    expect(api.apiKey, isNull);
    api.close(force: true);
  });

  test('cache cleanup does not delete persistent history directory', () async {
    final temp = await Directory.systemTemp.createTemp('hypixel_final_surface_');
    final api = HypixelApi(dataFolder: temp.path);

    final historyFile = File(
      '${api.dataStore.historyDirectory.path}${Platform.pathSeparator}sentinel.json',
    );
    await historyFile.parent.create(recursive: true);
    await historyFile.writeAsString('{}');

    await api.clearCache();

    expect(await historyFile.exists(), isTrue);
    api.close(force: true);
    await temp.delete(recursive: true);
  });
}
