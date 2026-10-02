import 'dart:io';

import 'package:hypixel_api/hypixel_api.dart';
import 'package:test/test.dart';

void main() {
  test('custom data folder is preserved and cache is isolated below it', () {
    final folder = '${Directory.systemTemp.path}${Platform.pathSeparator}hypixel_api_test_custom';
    final api = HypixelApi(dataFolder: folder);
    expect(api.dataFolder, folder);
    expect(api.cache.directory.path, contains('${Platform.pathSeparator}cache${Platform.pathSeparator}requests'));
  });

  test('default data folder lives under system temp', () {
    final api = HypixelApi();
    expect(api.dataFolder, contains(Directory.systemTemp.path));
    expect(api.dataFolder, endsWith('hypixel_api'));
  });
}
