/**
 * This is an example of how to set up the [EventBus] and its events.
 */
import 'package:event_bus/event_bus.dart';

/// The global [EventBus] object.
EventBus eventBus = EventBus();

/// Net Change Event
class NetChangeEvent {
  String text;

  NetChangeEvent(this.text);
}

/// Token Expired Event.
class TokenExpiredEvent {
  String text;

  TokenExpiredEvent(this.text);
}

/// Token Expired Event.
class StationNotOnlineEvent {
  String text;

  StationNotOnlineEvent(this.text);
}

/// Token Expired Event.
class RefreshEvent {
  String dirUUID;
  RefreshEvent(this.dirUUID);
}
