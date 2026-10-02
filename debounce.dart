import 'dart:async';

class Debouncer {
  Debouncer(this.delay);
  final Duration delay;
  Timer? _t;
  void run(void Function() cb) {
    _t?.cancel();
    _t = Timer(delay, cb);
  }

  void dispose() => _t?.cancel();
}
