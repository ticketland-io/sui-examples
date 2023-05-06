module examples::sword {
  use sui::object::{Self, UID};
  use sui::transfer;
  use sui::tx_context::{Self, TxContext};

  struct Sword has key, store {
    id: UID,
    magic: u64,
    strength: u64,
  }

  struct Forge has key, store {
    id: UID,
    swords_created: u64,
  }

  /// Module initializer to be executed when this module is published by the the Sui runtime
  fun init (ctx: &mut TxContext) {
    let admin = Forge {
      id: object::new(ctx),
      swords_created: 0,
    };

    // Transfer the forge object to the module/package publisher
    // Note SUI does not use the Move global storage. Instead it uses the SUI internal storage.
    // As such, Move global storage operators i.e. move_to, move_from, borrow_global and borrow_global_mut
    // are not available. Instead we use specific API to transfer object to an account
    //
    // From the `transfer` docs:
    //
    // Transfer ownership of `obj` to `recipient`. `obj` must have the `key` attribute,
    // which (in turn) ensures that `obj` has a globally unique ID. Note that if the recipient
    // address represents an object ID, the `obj` sent will be inaccessible after the transfer
    // (though they will be retrievable at a future date once new features are added).
    // This function has custom rules performed by the Sui Move bytecode verifier that ensures
    // that `T` is an object defined in the module where `transfer` is invoked. Use
    // `public_transfer` to transfer an object with `store` outside of its module.
    transfer::transfer(admin, tx_context::sender(ctx));
  }

  public fun magic(self: &Sword): u64 {
    self.magic
  }

  public fun strength(self: &Sword): u64 {
    self.strength
  }

  public fun swords_created(self: &Forge): u64 {
    self.swords_created
  }

  #[test(recipient = @0xCAFE)]
  fun test_sword_create(recipient: address) {
    use sui::tx_context;
    use sui::transfer::transfer;

    // create a test context
    let ctx = tx_context::dummy();

    let sword = Sword {
      id: object::new(&mut ctx),
      magic: 20,
      strength: 100,
    };

    assert!(magic(&sword) == 20 && strength(&sword) == 100, 1);
    
    transfer(sword, recipient);
  }
}
