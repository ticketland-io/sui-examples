module examples::clock {
  use sui::clock::{Self, Clock};
  use sui::event;

  struct TimeEvent has copy, drop, store {
    ts_ms: u64,
  }

  entry fun access(clock: &Clock) {
    event::emit(TimeEvent {
      ts_ms: clock::timestamp_ms(clock),
    });
  }
}
