/// Custom package upgrade policy that only authorizes upgrades on a particular day
/// of the week (of the package creator's choosing).
/// Package upgrades must occur end-to-end in a single transaction block and are composed of three commands:
/// 
/// 1. Authorization: Get permission from the UpgradeCap to perform the upgrade, creating an UpgradeTicket.
/// 2. Execution: Consume the UpgradeTicket and verify the package bytecode and compatibility against the previous
///    version, and create the on-chain object representing the upgraded package. Return an UpgradeReceipt as a result on success.
/// 3. Commit: Update the UpgradeCap with information about the newly created package.
module examples::day_of_week_policy {
  use sui::object::{Self, UID};
  use sui::package;
  use sui::tx_context::{Self, TxContext};

  struct UpgradeCap has key, store {
    id: UID,
    cap: package::UpgradeCap,
    day: u8,
  }

  /// Day is not a week day (number in range 0 <= day < 7).
  const ENotWeekDay: u64 = 1;
  // Request to authorize upgrade on the wrong day of the week.
  const ENotAllowedDay: u64 = 2;

  const MS_IN_DAY: u64 = 24 * 60 * 60 * 1000;

  public fun new_policy(
    cap: package::UpgradeCap,
    day: u8,
    ctx: &mut TxContext,
  ): UpgradeCap {
    assert!(day < 7, ENotWeekDay);

    UpgradeCap {
      id: object::new(ctx),
      cap,
      day,
    }
  }

  /// get the current weekday
  /// This function uses the epoch timestamp from TxContext rather than Clock because it needs only daily
  /// granularity,which means the upgrade transactions don't require consensus (Clock is a shared object)
  fun week_day(ctx: &TxContext): u8 {
    let days_since_unix_epoch = tx_context::epoch_timestamp_ms(ctx) / MS_IN_DAY;
    // The unix epoch (1st Jan 1970) was a Thursday so shift days
    // since the epoch by 3 so that 0 = Monday.
    ((days_since_unix_epoch + 3) % 7 as u8)
  }

  /// Check that the correct custom upgrade requirement are met i.e. the day of the week is correct
  public fun authorize_upgrade(
    cap: &mut UpgradeCap,
    policy: u8,
    digest: vector<u8>,
    ctx: &TxContext,
  ): package::UpgradeTicket {
    assert!(week_day(ctx) == cap.day, ENotAllowedDay);
    package::authorize_upgrade(&mut cap.cap, policy, digest)
  }

  public fun commit_upgrade(
    cap: &mut UpgradeCap,
    receipt: package::UpgradeReceipt,
  ) {
    package::commit_upgrade(&mut cap.cap, receipt)
  }

  public entry fun make_immutable(cap: UpgradeCap) {
    let UpgradeCap { id, cap, day: _ } = cap;
    object::delete(id);
    package::make_immutable(cap);
  }
}
