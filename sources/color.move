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
}
