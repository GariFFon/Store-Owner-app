import 'dart:async';

class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();

  final _controller = StreamController<dynamic>.broadcast();

  Stream<T> on<T>() {
    return _controller.stream.where((event) => event is T).cast<T>();
  }

  void fire(dynamic event) {
    _controller.add(event);
  }
}

class OrderPlacedEvent {}

class OrderStatusUpdatedEvent {}

class NavigateToTabEvent {
  final String tabName;
  NavigateToTabEvent(this.tabName);
}
