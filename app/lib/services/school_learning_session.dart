import 'dart:async';

/// One school-mode screen generation's permission to write local learning data.
///
/// Reset closes the generation before waiting for its already-started writes.
/// A callback that resumes later keeps its old generation and cannot recreate
/// deleted records. A new screen receives a new instance only after reset ends.
class SchoolLearningSession {
  bool _closed = false;
  final Set<Future<void>> _pending = {};

  Future<T> write<T>(Future<T> Function() operation) {
    if (_closed) {
      return Future<T>.error(StateError('school learning session is closed'));
    }
    final settled = Completer<void>();
    _pending.add(settled.future);
    return Future<T>.sync(operation).whenComplete(() {
      _pending.remove(settled.future);
      settled.complete();
    });
  }

  Future<void> closeAndDrain() async {
    _closed = true;
    // Settled signals complete even if a write failed. The original caller
    // still receives its error; reset then removes whatever was committed.
    await Future.wait(_pending.toList());
  }
}
