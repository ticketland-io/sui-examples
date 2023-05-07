/// Publishing a coin is Sui is almost as simple as publishing a new type using a One Time Witness pattern
module examples::suit_pepe {
  use std::option;
  use sui::coin;
  use sui::transfer;
  use sui::tx_context::{Self, TxContext};

  /// The type identifier of coin. The coin will have a type
  /// tag of kind: `Coin<package_object::pepe::PEPE>`
  /// Note! The name of the type matches the module's name (snake uppercased)
  struct SUIT_PEPE has drop {}

  /// Module initializer is called once on module publish. A treasury
  /// cap is sent to the publisher, who then controls minting and burning
  fun init(otw: SUIT_PEPE, ctx: &mut TxContext) {
    let (treasury, metadata) = coin::create_currency(
      otw,
      6,
      b"SUIT_PEPE",
      b"Suit Pepe",
      b"Suit pepe coin on Sui",
      option::none(),
      ctx,
    );

    // After freezing `obj` becomes immutable and can no longer be transferred or mutated.
    // Basically, we dissallow any changes to the suit pepe coin metadata
    transfer::public_freeze_object(metadata);

    // The Coin<T> is a generic implementation of a Coin on Sui. Owner of the TreasuryCap gets control over
    // the minting and burning of coins. Further transactions can be sent directly to the sui::coin::Coin with
    // TreasuryCap object as authorization.
    transfer::public_transfer(treasury, tx_context::sender(ctx));
  }
}
