class HypixelApiRateLimitState {
  const HypixelApiRateLimitState({
    required this.limit,
    required this.remaining,
    required this.resetAfter,
    required this.observedAt,
  });

  /// Hypixel's current response-header limit.
  final int limit;
  final int remaining;
  final Duration resetAfter;
  final DateTime observedAt;

  DateTime get resetAt => observedAt.add(resetAfter);
  bool get exhausted => remaining <= 0;
}
