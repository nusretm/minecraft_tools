import 'package:hypixel_api/hypixel_api.dart';
import 'package:test/test.dart';

void main() {
  test('API key metadata supports development/personal/production without hardcoded limits', () {
    final key = HypixelApiKey(
      value: 'key',
      type: HypixelApiKeyType.production,
      requestLimit: 1200,
      requestWindow: const Duration(minutes: 5),
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    );

    expect(key.type, HypixelApiKeyType.production);
    expect(key.requestLimit, 1200);
    expect(key.requestWindow, const Duration(minutes: 5));
    expect(key.isExpired, false);
    expect(key.remainingLifetime, isNotNull);
  });

  test('HypixelApi can replace its API key at runtime', () {
    final api = HypixelApi(apiKey: const HypixelApiKey(
      value: 'first',
      type: HypixelApiKeyType.development,
    ));

    expect(api.apiKey?.value, 'first');

    api.updateApiKey(const HypixelApiKey(
      value: 'second',
      type: HypixelApiKeyType.production,
      requestLimit: 900,
      requestWindow: Duration(minutes: 5),
    ));

    expect(api.apiKey?.value, 'second');
    expect(api.apiKey?.type, HypixelApiKeyType.production);
    expect(api.apiKey?.requestLimit, 900);
    api.close(force: true);
  });

  test('HypixelApi does not embed a default API key', () {
    final api = HypixelApi();
    expect(api.apiKey, isNull);
    api.close(force: true);
  });
}
