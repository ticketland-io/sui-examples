module examples::sword {
  use sui::object::{Self, UID};
  use sui::transfer;
  use sui::tx_context::{Self, TxContext};

  // To define a struct that represents a Sui object type, you must add a key capability to the definition.
  // The first field of the struct must be the id of the object with type UID from the object module
  //
  // Important: In both core Move and Sui Move, the key ability denotes a type that can appear as a key in global storage.
  // However, the structure of global storage is a bit different: core Move uses a (type, address)-indexed map,
  // whereas Sui Move uses a map keyed by object IDs.
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
    //
    // Objects in Sui can have different ownership types:
    // 1. Exclusively owned by an address.
    // 2. Exclusively owned by another object.
    // 3. Immutable (`transfer::freeze_object(obj)`)
    // 4. Shared (`transfer::share_object(obj)`)
    //
    // An object can be owned by another object when you add the former as a dynamic object field of the latter.
    // While external tools can read the dynamic object field value at its original ID, from Move's perspective,
    // you can only access it through the field on its owner using the dynamic_object_field APIs:
    //
    // 
    // ```move
    // use sui::dynamic_object_field as ofield;
    // 
    // let a: &mut A = /* ... */;
    // let b: B = /* ... */;
    // 
    // // Adds `b` as a dynamic object field to `a` with "name" `0: u8`.
    // ofield::add<u8, B>(&mut a.id, 0, b);
    // 
    // // Get access to `b` at its new position
    // let b: &B = ofield::borrow<u8, B>(&a.id, 0);
    // ```
    // 
    // If you pass the value of a dynamic object field as an input to an entry function in a transaction,
    // that transaction fails. For instance, if you have a chain of ownership: address Addr1 owns object a,
    // object a has a dynamic object field containing object b, and b has a dynamic object field containing 
    // object c, then in order to use object c in a Move call, Addr1 must sign the transaction and accept a 
    // as an input, and you must access b and c dynamically during transaction execution:
    //
    // ```move
    //   use sui::dynamic_object_field as ofield;
    //
    //   // Signer of ctx is Addr1
    //   public entry fun entry_function(a: &A, ctx: &mut TxContext) {
    //     let b: &B = ofield::borrow<u8, B>(&a.id, 0);
    //     let c: &C = ofield::borrow<u8, C>(&b.id, 0);
    //   }
    // ```
    transfer::transfer(admin, tx_context::sender(ctx));
  }

  // For a transaction to make a call to the create_sword function, the sender of the
  // transaction must be the owner of  the forge  object
  public fun create_sword(forge: &mut Forge, magic: u64, strength: u64, recipient: address, ctx: &mut TxContext) {
    let sword = Sword {
      id: object::new(ctx),
      magic,
      strength,
    };

    transfer::transfer(sword, recipient);

    forge.swords_created = forge.swords_created + 1;
  }

  public entry fun sword_transfer(sword: Sword, recipient: address, _ctx: &mut TxContext) {
    transfer::transfer(sword, recipient);
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

  // This is a unit test
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

  // This test is more of an integration test emulating real transactions
  #[test(admin = @0xBABE, initial_owner=@0xCAFE, final_owner=@0xFACE)]
  fun test_sword_transactions(admin: address, initial_owner: address, final_owner: address) {
    use sui::test_scenario;

    // first transaction to emulate module initialization
    // The test_scenario module provides a scenario that emulates a series of Sui transactions,
    // each with a potentially different user executing them. A test using this module typically starts
    // the first transaction using the test_scenario::begin function. This function takes an address of
    // the user executing the transaction as its argument and returns an instance of the Scenario struct
    // representing a scenario. An instance of the Scenario struct contains a per-address object pool emulating
    // Sui object storage, with helper functions provided to manipulate objects in the pool. After the first  
    // transaction finishes, subsequent test transactions start with the test_scenario::next_tx function. This function
    // takes an instance of the Scenario struct representing the current scenario and an address of a user as arguments.
    let scenario_val = test_scenario::begin(admin);
    init(test_scenario::ctx(&mut scenario_val));

    // second transaction executed by admin to create the sword
    test_scenario::next_tx(&mut scenario_val, admin);
    let forge = test_scenario::take_from_sender<Forge>(&mut scenario_val);
    create_sword(&mut forge, 20, 100, initial_owner, test_scenario::ctx(&mut scenario_val));
    test_scenario::return_to_sender(&mut scenario_val, forge);

    // Asser that swords_created is updated
    // Important: Transaction effects, such as object creation and transfer become visible only after a given
    // transaction completes. For example, if the second transaction in the running example created a sword and
    // transferred it to the administrator's address, it would only become available for retrieval from the administrator's
    // address (via test_scenario, take_from_sender, or take_from_address functions) in the third transaction.
    // This is why we need to init the next transaction to get the updated value of the forge object.
    test_scenario::next_tx(&mut scenario_val, admin);
    let forge = test_scenario::take_from_sender<Forge>(&mut scenario_val);
    assert!(swords_created(&forge) == 1, 1);
    test_scenario::return_to_sender(&mut scenario_val, forge);

    // third transaction executed by the initial sword owner
    test_scenario::next_tx(&mut scenario_val, initial_owner);
    // extract the sword owned by the initial owner
    // In pure Move there is no notion of Sui storage; consequently, there is no easy way for the emulated Sui transaction
    // to retrieve it from storage. This is where the test_scenario module helps - its take_from_sender function allows an
    // object of a given type (Sword) that is owned by an address executing the current transaction to be available for Move
    // code manipulation.
    let sword = test_scenario::take_from_sender<Sword>(&mut scenario_val);
    // transfer the sword to the final owner
    sword_transfer(sword, final_owner, test_scenario::ctx(&mut scenario_val));

    // fourth transaction executed by the final sword owner
    test_scenario::next_tx(&mut scenario_val, final_owner);
    // extract the sword owned by the final owner
    let sword = test_scenario::take_from_sender<Sword>(&mut scenario_val);
    assert!(magic(&sword) == 20 && strength(&sword) == 100, 1);
    // return the sword to the object pool (it cannot be simply "dropped")
    test_scenario::return_to_sender(&mut scenario_val, sword);

    test_scenario::end(scenario_val);
  }

  #[test(admin = @0xBABE)]
  public fun test_module_init(admin: address) {
    use sui::test_scenario;

    // First transaction to emulate module initialization
    let scenario_val = test_scenario::begin(admin);
    init(test_scenario::ctx(&mut scenario_val));

    // Second transaction to check if the forge has been created
    // and has initial value of zero swords created
    test_scenario::next_tx(&mut scenario_val, admin);
    let forge = test_scenario::take_from_sender<Forge>(&mut scenario_val);
    assert!(swords_created(&forge) == 0, 1);
    
    // Return the Forge object to the object pool
    test_scenario::return_to_sender(&mut scenario_val, forge);

    test_scenario::end(scenario_val);
}
}
