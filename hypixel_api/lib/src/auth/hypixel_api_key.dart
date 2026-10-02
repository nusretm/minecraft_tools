enum HypixelApiKeyType {
  development,
  personal,
  production,
}

class HypixelApiKey {
  const HypixelApiKey({
    required this.value,
    required this.type,
    this.expiresAt,
    this.requestLimit,
    this.requestWindow,
  });

  final String value;
  final HypixelApiKeyType type;

  /// Optional absolute expiration supplied by the Hypixel dashboard/backend.
  final DateTime? expiresAt;

  /// Configured/dashboard limit for this key. Do not infer this from [type]:
  /// production applications can be granted a larger limit.
  final int? requestLimit;

  /// Window associated with [requestLimit], e.g. five minutes.
  final Duration? requestWindow;

  bool get isExpired {
    final expiry = expiresAt;
    return expiry != null && !DateTime.now().toUtc().isBefore(expiry.toUtc());
  }

  Duration? get remainingLifetime {
    final expiry = expiresAt;
    if (expiry == null) return null;
    final remaining = expiry.toUtc().difference(DateTime.now().toUtc());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  HypixelApiKey copyWith({
    String? value,
    HypixelApiKeyType? type,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
    int? requestLimit,
    bool clearRequestLimit = false,
    Duration? requestWindow,
    bool clearRequestWindow = false,
  }) =>
      HypixelApiKey(
        value: value ?? this.value,
        type: type ?? this.type,
        expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
        requestLimit: clearRequestLimit ? null : (requestLimit ?? this.requestLimit),
        requestWindow: clearRequestWindow ? null : (requestWindow ?? this.requestWindow),
      );
}
