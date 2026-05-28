import 'dart:async';

/// Coalesces rapid callbacks (e.g. search keystrokes) to reduce rebuild work.
class Debouncer {
  Debouncer({this.duration = const Duration(milliseconds: 280)});

  final Duration duration;
  Timer? _timer;

  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  void cancel() => _timer?.cancel();

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
