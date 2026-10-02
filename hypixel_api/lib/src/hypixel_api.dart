import 'auth/hypixel_api_key.dart';
import 'auth/hypixel_api_rate_limit_state.dart';
import 'cache/hypixel_file_cache.dart';
import 'history/hypixel_data_store.dart';
import 'http/hypixel_http_client.dart';
import 'skyblock/hypixel_skyblock_api.dart';

class HypixelApi {
  HypixelApi({
    DateTime? now,
    String? dataFolder,
    HypixelApiKey? apiKey,
    Duration electionCacheTtl = const Duration(minutes: 5),
    Duration bingoResourceCacheTtl = const Duration(minutes: 5),
    Duration bingoPlayerCacheTtl = const Duration(minutes: 5),
    Duration newsCacheTtl = const Duration(minutes: 15),
  }) {
    _apiKey = apiKey;
    dataStore = HypixelDataStore(folder: dataFolder);
    cache = HypixelFileCache(directory: dataStore.cacheDirectory);
    _http = HypixelHttpClient(cache: cache);
    skyBlock = HypixelSkyBlockApi(
      http: _http,
      dataStore: dataStore,
      now: now,
      electionCacheTtl: electionCacheTtl,
      bingoResourceCacheTtl: bingoResourceCacheTtl,
      bingoPlayerCacheTtl: bingoPlayerCacheTtl,
      newsCacheTtl: newsCacheTtl,
      apiKeyProvider: () => _apiKey,
    );
  }

  HypixelApiKey? _apiKey;
  late final HypixelDataStore dataStore;
  late final HypixelFileCache cache;
  late final HypixelHttpClient _http;
  late final HypixelSkyBlockApi skyBlock;

  HypixelApiKey? get apiKey => _apiKey;
  HypixelApiRateLimitState? get rateLimit => _http.rateLimitState;
  String get dataFolder => dataStore.rootDirectory.path;

  /// Replaces the key used by subsequent authenticated requests.
  /// Cached data and history are not cleared automatically.
  void updateApiKey(HypixelApiKey? apiKey) {
    _apiKey = apiKey;
  }

  Future<void> clearCache() => cache.clear();
  Future<int> clearExpiredCache() => cache.clearExpired();

  /// Optional explicit teardown. HTTP requests themselves are non-persistent,
  /// so CLI/process shutdown does not depend on calling this method.
  void close({bool force = false}) => _http.close(force: force);
}
