import 'dart:async';

import 'app_events.dart';

/// In-process publish/subscribe channel between micro apps.
class EventBus {
  final _controller = StreamController<AppEvent>.broadcast();

  void publish(AppEvent event) => _controller.add(event);

  /// Typed subscription: `bus.on<PixSentEvent>().listen(...)`.
  Stream<T> on<T extends AppEvent>() => _controller.stream.where((e) => e is T).cast<T>();

  Future<void> dispose() => _controller.close();
}
