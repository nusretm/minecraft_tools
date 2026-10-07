import 'dart:async';

import '../model/minecraft_content_models.dart';
import 'minecraft_content_provider_models.dart';

abstract class MtnMinecraftContentProvider {
  MtnMinecraftContentProvider({
    required this.name,
  }) {
    if (name.isEmpty) throw ArgumentError.value(name, 'name', 'Provider name cannot be empty.');
    if (name.trim() != name) throw ArgumentError.value(name, 'name', 'Provider name cannot contain leading or trailing whitespace.');
  }

  final String name;

  bool get ready;

  int? _rateLimitLimit;
  int? _rateLimitRemaining;
  DateTime? _rateLimitResetAt;
  Future<void> _requestTail = Future<void>.value();

  MtnMinecraftContentProviderRateLimit get rateLimit {
    _expireRateLimitIfNeeded();
    return MtnMinecraftContentProviderRateLimit(
      limit: _rateLimitLimit,
      remaining: _rateLimitRemaining,
      resetAt: _rateLimitResetAt,
    );
  }

  MtnMinecraftContentProvider requireReady() {
    if (!ready) throw MtnMinecraftContentProviderNotReadyException(providerName: name);
    return this;
  }

  Future<T> runRequest<T>(Future<T> Function() request) {
    requireReady();

    final completer = Completer<T>();

    _requestTail = _requestTail.then((_) async {
      try {
        requireReady();
        await waitForRequestAvailability();
        requireReady();
        completer.complete(await request());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });

    return completer.future;
  }

  void updateRateLimit({
    int? limit,
    int? remaining,
    Duration? resetAfter,
  }) {
    if (limit != null && limit < 0) throw ArgumentError.value(limit, 'limit', 'Rate-limit limit cannot be negative.');
    if (remaining != null && remaining < 0) throw ArgumentError.value(remaining, 'remaining', 'Rate-limit remaining cannot be negative.');
    if (resetAfter != null && resetAfter.isNegative) throw ArgumentError.value(resetAfter, 'resetAfter', 'Rate-limit reset duration cannot be negative.');

    if (limit != null) _rateLimitLimit = limit;
    if (remaining != null) _rateLimitRemaining = remaining;
    if (resetAfter != null) _rateLimitResetAt = DateTime.now().add(resetAfter);
  }

  void throttleRequests(Duration retryAfter) {
    if (retryAfter.isNegative) throw ArgumentError.value(retryAfter, 'retryAfter', 'Retry duration cannot be negative.');

    _rateLimitRemaining = 0;
    _rateLimitResetAt = DateTime.now().add(retryAfter);
  }

  Future<void> waitForRequestAvailability() async {
    while (true) {
      _expireRateLimitIfNeeded();

      final remaining = _rateLimitRemaining;
      final resetAt = _rateLimitResetAt;
      if (remaining == null || remaining > 0 || resetAt == null) return;

      final delay = resetAt.difference(DateTime.now());
      if (delay <= Duration.zero) {
        _expireRateLimitIfNeeded();
        return;
      }

      await Future<void>.delayed(delay);
    }
  }

  void _expireRateLimitIfNeeded() {
    final resetAt = _rateLimitResetAt;
    if (resetAt == null || resetAt.isAfter(DateTime.now())) return;

    _rateLimitRemaining = null;
    _rateLimitResetAt = null;
  }

  Future<Uri?> resolveDownloadSource(MtnMinecraftContentVersion version, MtnMinecraftContentFile file) async {
    requireReady();
    if (!version.files.any((item) => identical(item, file))) throw ArgumentError.value(file, 'file', 'Download-source file must belong to the supplied version.');
    return null;
  }

  Future<MtnMinecraftContentSearchResult> search(MtnMinecraftContentSearchRequest request);

  Future<MtnMinecraftContent> getContent(String id);

  Future<MtnMinecraftContentVersion> getVersion(String id);

  Future<MtnMinecraftContentVersionListResult> getVersions(MtnMinecraftContent content, MtnMinecraftContentVersionListRequest request);
}

class MtnMinecraftContentProviderRateLimit {
  const MtnMinecraftContentProviderRateLimit({
    this.limit,
    this.remaining,
    this.resetAt,
  });

  final int? limit;
  final int? remaining;
  final DateTime? resetAt;

  bool get limited {
    final remaining = this.remaining;
    final resetAt = this.resetAt;
    return remaining != null && remaining <= 0 && resetAt != null && resetAt.isAfter(DateTime.now());
  }

  Duration? get resetIn {
    final resetAt = this.resetAt;
    if (resetAt == null) return null;

    final value = resetAt.difference(DateTime.now());
    return value <= Duration.zero ? Duration.zero : value;
  }
}

class MtnMinecraftContentProviderNotReadyException implements Exception {
  const MtnMinecraftContentProviderNotReadyException({
    required this.providerName,
  });

  final String providerName;

  @override
  String toString() => 'MtnMinecraftContentProviderNotReadyException(providerName=$providerName)';
}
