typedef ChallengeElapsedClock = Duration Function();

/// A monotonic, in-memory deadline for optional timed challenges.
///
/// [Stopwatch] keeps advancing while the app is backgrounded, unlike a
/// decrementing UI timer. No start time, elapsed time, or answer is persisted.
/// Tests may inject an elapsed clock so lifecycle transitions stay deterministic.
class ChallengeDeadline {
  ChallengeDeadline(Duration limit, {ChallengeElapsedClock? elapsedClock})
    : assert(limit > Duration.zero),
      _limit = limit,
      _elapsedClock = elapsedClock,
      _stopwatch = elapsedClock == null ? Stopwatch() : null;

  Duration _limit;
  final ChallengeElapsedClock? _elapsedClock;
  final Stopwatch? _stopwatch;
  Duration? _startedAt;

  bool get isRunning => _startedAt != null || (_stopwatch?.isRunning ?? false);

  int get initialSeconds =>
      (_limit.inMicroseconds / Duration.microsecondsPerSecond).ceil().clamp(
        1,
        24 * 60 * 60,
      );

  int get remainingSeconds {
    final remaining = _limit - _elapsed;
    if (remaining <= Duration.zero) return 0;
    return (remaining.inMicroseconds / Duration.microsecondsPerSecond)
        .ceil()
        .clamp(1, initialSeconds);
  }

  void start() {
    if (_elapsedClock case final clock?) {
      _startedAt = clock();
      return;
    }
    _stopwatch!
      ..reset()
      ..start();
  }

  void reset({Duration? limit}) {
    if (limit != null) {
      if (limit <= Duration.zero) {
        throw ArgumentError.value(limit, 'limit', 'must be positive');
      }
      _limit = limit;
    }
    _startedAt = null;
    _stopwatch
      ?..stop()
      ..reset();
  }

  void stop() {
    _stopwatch?.stop();
  }

  Duration get _elapsed {
    if (_elapsedClock case final clock?) {
      final startedAt = _startedAt;
      if (startedAt == null) return Duration.zero;
      final elapsed = clock() - startedAt;
      return elapsed.isNegative ? Duration.zero : elapsed;
    }
    return _stopwatch?.elapsed ?? Duration.zero;
  }
}
