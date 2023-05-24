module examples::dynamic_field_reflection {
  use sui::object::UID;
  use sui::object;
  use sui::tx_context::{TxContext};
  use sui::dynamic_field as dfield;
  use std::type_name;
  
  struct DynamicParentField has key, store {
    id: UID,
    root: u64,
  }

  struct DynamicChild_1 has store, drop {
    val: u64,
  }

  struct DynamicChild_2 has store, drop {
    val: u64,
    val2: u64,
  }

  fun extract_dynamic_child_1(c: &DynamicChild_1): u64 {
    return c.val
  }

  public entry fun reflection<T: store>(ctx: &mut TxContext) {
    let parent_1 = DynamicParentField {
      id: object::new(ctx),
      root: 10,
    };

    let c1 = DynamicChild_1 {val: 10};
    let _ = DynamicChild_2 {val: 20, val2: 30};

    dfield::add(&mut parent_1.id, b"child", c1);

    let parent_2 = DynamicParentField {
      id: object::new(ctx),
      root: 0,
    };

    let _ = DynamicChild_1 {val: 10};
    let c2 = DynamicChild_2 {val: 20, val2: 30};

    dfield::add(&mut parent_2.id, b"child", c2);

    // Access the first parent child. Pretend that we don't know the exact type and we want to
    // use some type of reflection to get it;
    let _: &T = dfield::borrow(&parent_1.id, b"child");

    // what's the type of T?
    let t = type_name::get<T>();
    let _m_name = &type_name::get_module(&t);
    let _addr = &type_name::get_address(&t);
    
    // let say at this point we check the type and we know that it's DynamicChild_1. Now we can re-borrow the same value
    // again but providing the concrete type.
    let c1: &DynamicChild_1 = dfield::borrow(&parent_1.id, b"child");
    extract_dynamic_child_1(c1);

    // Alternative solution. A much better aproach!!!!!!!!!!!!
    if(dfield::exists_with_type<vector<u8>, DynamicChild_1>(&parent_1.id, b"child")) {
      // this is a DynamicChild_1
    } else if(dfield::exists_with_type<vector<u8>, DynamicChild_2>(&parent_1.id, b"child")) {
      // this is a DynamicChild_1
    };


    // destroy for our example since Objects are not droppable
  let DynamicParentField {id, root: _} = parent_1;
    object::delete(id);
    let DynamicParentField {id, root: _} = parent_2;
    object::delete(id);
  } 
}
