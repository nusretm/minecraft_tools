# CP-12 — Centralized HTTP Response Cache for Minecraft Content Service

## Status — 2026-10-18

- User explicitly approved implementation after reviewing repeated Modrinth version-list HTTP calls. Main already uses CP-11 for stable encrypted game-record filenames; this bounded HTTP checkpoint is **CP-12** to avoid duplicate numbering.
- Feature branch: `feature/minecraft-content-central-http-cache`; draft PR pending Windows validation and separate merge approval.
- First user Windows run: `dart pub get` succeeded but `dart analyze` found **3 compile errors** caused by a single invalid mixed positional/named constructor in `minecraft_content_provider_list.dart`. Therefore focused, provider, full tests and live smoke could not load; these results are **blocked**, not genuine runtime test failures. The constructor was changed to valid optional positional parameters while preserving the existing registry API, and the service forwards `cacheDuration` positionally (fix commits `a299386`, `6ba863b`). **Post-fix Windows analyzer/tests/live smoke PENDING.**
- `docs/WORKING_RULES.md` applies. Never run `dart format` for pure Dart.

## User-approved scope

- **Single HTTP transport/cache owner**: `MtnMinecraftContentHttpService` is responsible for outgoing GET/read-only POST calls across Modrinth and CurseForge. No direct `_client.get` / `_client.post` in providers.
- `MtnMinecraftContentProviderList` owns one transport instance and assigns it to all registered providers, including late registration. A directly constructed standalone provider has its own default HTTP authority.
- Request key is **SHA-256** of HTTP method, canonical URL with sorted query parameter names/values, request headers (including authorization scope), and request body. Do not persist raw credentials in keys.
- Cache stores successful HTTP responses in memory for **1 hour by default**. Caller can change `cacheDuration` when creating `MtnMinecraftContentService` or a standalone HTTP service. `Duration.zero` disables completed-response caching.
- Concurrent identical requests share one pending Future, before provider rate-limit queue. Expired responses are re-fetched; cache can be cleared; max cached responses defaults to 256 with bounded eviction.
- Non-2xx results including 429 do not enter the completed cache. Existing provider request serialization, provider-specific rate-limit observations and bounded HTTP 429 retry remain.
- **CurseForge presigned/short-lived download-url endpoint is excluded**. CurseForge's read-only POST `/v1/mods/files` is cacheable by body plus API key; headers participate in cache key to prevent cross-credential leakage.
- Existing Modrinth local pagination already reissues an identical full-list URL for different offsets. HTTP response caching makes repeated page requests reuse the first result without new network traffic. No separate pagination engine or model cache added.
- No persistent disk cache, UI changes, model schema changes, new dependency, Content Server polling, or download manager changes.
- Existing Package hydration metadata cache remains untouched; this checkpoint operates strictly beneath providers at HTTP level.

## Usage

```dart
final service = MtnMinecraftContentService(
  providers: <MtnMinecraftContentProvider>[modrinth, curseForge],
  cacheDuration: const Duration(hours: 1), // customizable
);

// All registered providers share one central HTTP/cache instance:
final httpCache = service.providers.httpService;
print(httpCache.cachedResponseCount);
httpCache.clear();
```

## Verification gate (Windows)

```powershell
cd D:\development\cross-platform\minecraft_tools
git fetch origin feature/minecraft-content-central-http-cache
git switch --track origin/feature/minecraft-content-central-http-cache

cd minecraft_content_service
dart pub get
dart analyze
dart test test/content_http_cache_test.dart -r expanded
dart test test/content_provider_modrinth_test.dart test/content_provider_curseforge_test.dart test/content_provider_service_test.dart -r expanded
dart test
dart run example/content_http_cache_modrinth.dart 6qAuTtLR

cd ..
git diff --check main...HEAD
git status
```

Live example must show repeated exact-version and local-version-list calls performing **zero additional HTTP requests**, with actual Modrinth responses. Unit tests cover normalized URL/order, in-flight dedup, TTL, authorization/body isolation, HTTP errors and excluded expiring URL.
