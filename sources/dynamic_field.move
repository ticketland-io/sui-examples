/// Previous chapters describe various ways to use object fields to store primitive data and other objects (wrapping),
/// but there are a few limitations to this approach:
/// 
/// 1. Object's have a finite set of fields keyed by identifiers that are fixed when its module is published 
///    (i.e. limited to the fields in the struct declaration).
/// 2. An object can become very large if it wraps several other objects. Larger objects can lead to higher gas fees in
///    transactions. In addition, there is an upper bound on object size.
/// 3. Later chapters include use cases where you need to store a collection of objects of heterogeneous types. Since the Sui
///    Move vector type must be instantiated with one single type T, it is not suitable for this.
/// 
/// Fortunately, Sui provides dynamic fields with arbitrary names (not just identifiers), added and removed on-the-fly
/// (not fixed at publish), which only affect gas when they are accessed, and can store heterogeneous values.
/// 
/// There are two flavors of dynamic field -- "fields" and "object fields" -- which differ based on how their values are stored:
/// 
/// 1. Fields can store any value that has store, however an object stored in this kind of field will be considered wrapped
///    and will not be accessible via its ID by external tools (explorers, wallets, etc) accessing storage.
/// 2. Object field values must be objects (have the key ability, and id: UID as the first field), but will still be accessible
///    at their ID to external tools.
module examples::dynamic_field {
  use sui::object::UID;
  use sui::object;
  use sui::transfer;
  use sui::tx_context::{Self, TxContext};
  use sui::dynamic_object_field as ofield;

  struct Parent has key {
    id: UID,
  }

  struct Child has key, store {
    id: UID,
    count: u64,
  }

  /// This function takes the Child object by value and makes it a dynamic field of parent with name
  /// b"child" (a byte string of type vector<u8>). This call results in the following ownership relationship:
  /// 
  /// 1. Sender address (still) owns the Parent object
  /// 2. he Parent object owns the Child object, and can refer to it by the name b"child".
  public entry fun add_child(parent: &mut Parent, child: Child) {
    ofield::add(&mut parent.id, b"child", child);
  }

  public entry fun mutate_child(child: &mut Child) {
    child.count = child.count + 1;
  }

  /// accepts a mutable reference to the Parent object and accesses its dynamic field using borrow_mut, to pass to mutate_child.
  /// This can only be called on Parent objects that have a b"child" field defined. A Child object that has been added to a
  /// Parent must be accessed via its dynamic field, so it can only by mutated using mutate_child_via_parent, not mutate_child,
  /// even if its ID is known.
  /// 
  /// Important: A transaction that attempts to borrow a field that does not exist will fail.
  /// Dynamic object field values must be accessed through these APIs. A transaction that attempts to use those objects as
  /// inputs (by value or by reference), will be rejected for having invalid inputs.
  public entry fun mutate_child_via_parent(parent: &mut Parent) {
    // The Value type passed to borrow and borrow_mut must match the type of the stored field, or the transaction will abort.
    mutate_child(ofield::borrow_mut<vector<u8>, Child>(
      &mut parent.id,
      b"child",
    ));
  }

  // It is possible to delete an object that has dynamic fields still defined on it. Because field values can be accessed
  // only via the dynamic field's associated object and field name, deleting an object that has dynamic fields still defined
  // on it renders them all inaccessible to future transactions. This is true regardless of whether the field's value has the
  // drop ability.
  public entry fun delete_child(parent: &mut Parent) {
    // If a field with a value: Value is defined on object at name, it will be removed and value returned, otherwise
    // it will abort. Future attempts to access this field on object will fail.
    let Child {id, count: _} = ofield::remove<vector<u8>, Child>(
      &mut parent.id,
      b"child",
    );

    object::delete(id);
  }

  public entry fun reclaim_child(parent: &mut Parent, ctx: &mut TxContext) {
    let child = ofield::remove<vector<u8>, Child>(
      &mut parent.id,
      b"child",
    );

    transfer::transfer(child, tx_context::sender(ctx));
  }
}
