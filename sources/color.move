module examples::color {
  use sui::object::UID;
  use sui::object;
  use sui::transfer;
  use sui::tx_context::{Self, TxContext};

  struct ColorObject has key {
    id: UID,
    red: u8,
    green: u8,
    blue: u8,
  }

  fun new(red: u8, green: u8, blue: u8, ctx: &mut TxContext): ColorObject {
    ColorObject {
      id: object::new(ctx),
      red,
      green,
      blue,
    }
  }

  /// This is an entry function that you can call directly by a Transaction.
  public entry fun create(red: u8, green: u8, blue: u8, ctx: &mut TxContext) {
    let color_object = new(red, green, blue, ctx);
    transfer::transfer(color_object, tx_context::sender(ctx))
  }

  public fun get_color(self: &ColorObject): (u8, u8, u8) {
    (self.red, self.green, self.blue)
  }

  /// Copies the values of `from_object` into `into_object`.
  /// In the preceding function signature, from_object can be a read-only reference because you only need to
  /// read its fields. Conversely, into_object must be a mutable reference since you need to mutate it.
  /// For a transaction to make a call to the copy_into function, the sender of the transaction must be the
  /// owner of both from_object and into_object.
  /// 
  /// Although from_object is a read-only reference in this transaction, it is still a mutable object in Sui 
  /// storage--another transaction could be sent to mutate the object at the same time. To prevent this, Sui
  /// must lock any mutable object used as a transaction input, even when it's passed as a read-only reference.
  /// In addition, only an object's owner can send a transaction that locks the object.
  public entry fun copy_into(from_object: &ColorObject, into_object: &mut ColorObject) {
    into_object.red = from_object.red;
    into_object.green = from_object.green;
    into_object.blue = from_object.blue;
  }

  /// You can also pass objects by value into an entry function. By doing so, the object is moved out of Sui storage. 
  /// It is then up to the Sui Move code to decide where this object should go.
  /// Since every Sui object struct type must include UID as its first field, and the UID struct does not have the drop
  /// ability, the Sui object struct type cannot have the drop ability either. Hence, any Sui object cannot be arbitrarily
  /// dropped and must be either consumed (for example, transferred to another owner) or deleted by unpacking.
  public entry fun delete(object: ColorObject) {
    let ColorObject { id, red: _, green: _, blue: _ } = object;
    object::delete(id);
  }

  #[test(owner=@0x1)]
  fun test_copy_into(owner: address) {
    use sui::test_scenario;

    let scenario_val = test_scenario::begin(owner);

    // Create two ColorObjects owned by `owner`, and obtain their IDs
    let (id1, id2) = {
      let ctx = test_scenario::ctx(&mut scenario_val);
      create(255, 255, 255, ctx);
      
      // get the ID of the object the call created using `last_created_object_id`
      let id1 = object::id_from_address(tx_context::last_created_object_id(ctx));
      create(0, 0, 0, ctx);
      let id2 = object::id_from_address(tx_context::last_created_object_id(ctx));
      
      (id1, id2)
    };

    test_scenario::next_tx(&mut scenario_val, owner);
    {
      let obj1 = test_scenario::take_from_sender_by_id<ColorObject>(&mut scenario_val, id1);
      let obj2 = test_scenario::take_from_sender_by_id<ColorObject>(&mut scenario_val, id2);
      let (red, green, blue) = get_color(&obj1);
      
      assert!(red == 255 && green == 255 && blue == 255, 0);

      let _ = test_scenario::ctx(&mut scenario_val);
      copy_into(&obj2, &mut obj1);
      test_scenario::return_to_sender(&mut scenario_val, obj1);
      test_scenario::return_to_sender(&mut scenario_val, obj2);
    };

    test_scenario::next_tx(&mut scenario_val, owner);
    {
      let obj1 = test_scenario::take_from_sender_by_id<ColorObject>(&mut scenario_val, id1);
      let (red, green, blue) = get_color(&obj1);

      assert!(red == 0 && green == 0 && blue == 0, 0);
      
      test_scenario::return_to_sender(&mut scenario_val, obj1);
    };

    test_scenario::end(scenario_val);
  }
}
