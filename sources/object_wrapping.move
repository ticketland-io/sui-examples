/// When an object is wrapped, the object no longer exists independently on-chain. You can no longer look up the
/// object by its ID. The object becomes part of the data of the object that wraps it. Most importantly, you can
/// no longer pass the wrapped object as an argument in any way in Sui Move calls. The only access point is through
/// the wrapping object.
/// 
/// At some point, you can then take out the wrapped object and transfer it to an address. This is called unwrapping.
/// When an object is unwrapped, it becomes an independent object again, and can be accessed directly on-chain. There is
/// also an important property about wrapping and unwrapping: the object's ID stays the same across wrapping and unwrapping.
/// 
/// If you put a Sui object type directly as a field in another Sui object type (as in the preceding example), it is called
/// direct wrapping. The most important property achieved through direct wrapping is that the wrapped object cannot be
/// unwrapped unless the wrapping object is destroyed.
/// In the preceding example, to make Bar a standalone object again, delete (and hence unpack) the Foo object. Direct wrapping
/// is the best way to implement object locking, which is to lock an object with constrained access. You can unlock it only
/// through specific contract calls.
module examples::object_wrapping {
  use sui::object::UID;
  use std::option::{Self, Option};
  use sui::object;
  use sui::transfer;
  use sui::coin::{Self, Coin};
  use sui::balance::{Self, Balance};
  use sui::sui::SUI;
  use sui::tx_context::{Self, TxContext};

  const MIN_FEE: u64 = 1000;

  struct Foo has key {
    id: UID,
    bar: Bar,
  }

  // Bar is a normal struct, but it is not a Sui object since it doesn't have the key ability. This is common usage
  // to organize data with good encapsulation.
  struct Bar has store {
    value: u64,
  }

  // To put a Sui object struct type as a field in another Sui object struct type, change Bar into
  struct Bar2 has key, store {
    id: UID,
    value: u64,
  }

  // The following example implementation of a trusted swap demonstrates how to use direct wrapping. Assume there is an
  // NFT-style Object type that has scarcity and style. In this example, scarcity determines how rare the object 
  // is (presumably the more scarce the higher its market value), and style determines the object content/type or how 
  // it's rendered. If you own some of these objects and want to trade your objects with others, you want to make sure
  // it's a fair trade. You are willing to trade an object only with another one that has identical scarcity, but want
  // a different style (so that you can collect more styles).
  struct Object has key, store {
    id: UID,
    scarcity: u8,
    style: u8,
  }

  /// Anyone can call create_object to create a new object with specified scarcity and style. The created object is sent
  /// to the signer of the transaction. 
  public entry fun create_object(scarcity: u8, style: u8, ctx: &mut TxContext) {
    let object = Object {
      id: object::new(ctx),
      scarcity,
      style,
    };

    transfer::transfer(object, tx_context::sender(ctx))
  }

  public entry fun transfer_object(object: Object, recipient: address) {
    transfer::transfer(object, recipient)
  }

  /// #1 Direct Wrapping
  /// 
  /// You can also enable a swap/trade between your object and others' objects. For example, define a function that takes two
  /// objects from two addresses and swaps their ownership. But this doesn't work in Sui! Recall from Using Objects that only
  /// object owners can send a transaction to mutate the object. So one person cannot send a transaction that would swap their
  /// own object with someone else's object.Sui supports multi-signature (multi-sig) transactions so that two people can sign 
  /// he same transaction for this type of use case. But a multi-sig transaction doesn't work in this scenario.
  /// 
  /// Another common solution is to send your object to a pool - such as an NFT marketplace or a staking pool - and perform the
  /// swap in the pool (either right away, or later when there is demand). Other chapters explore the concept of shared objects
  /// that can be mutated by anyone, and show that how it enables anyone to operate in a shared object pool. This chapter focuses
  /// on how to achieve the same effect using owned objects. Transactions using only owned objects are faster and less expensive
  /// (in terms of gas) than using shared objects, since they do not require consensus in Sui.
  /// 
  /// To swap objects, the same address must own both objects. Anyone who wants to swap their object can send their objects to
  /// the third party, such as a site that offers swapping services, and the third party helps perform the swap and send the
  /// objects to the appropriate owner. To ensure that you retain custody of your objects (such as coins and NFTs) and not give
  /// full custody to the third party, use direct wrapping. To define a wrapper object type:
  struct ObjectWrapper has key {
    id: UID,
    original_owner: address,
    to_swap: Object,
    fee: Balance<SUI>,
  }

  /// You must pass the object by value so that it's fully consumed and wrapped into ObjectWrapperto request swapping an object
  /// The wrapper object is then sent to the service operator, with the address specified in the call as service_address.
  public entry fun request_swap(object: Object, fee: Coin<SUI>, service_address: address, ctx: &mut TxContext) {
    assert!(coin::value(&fee) >= MIN_FEE, 0);
    let wrapper = ObjectWrapper {
      id: object::new(ctx),
      original_owner: tx_context::sender(ctx),
      to_swap: object,
      // The example turns Coin into Balance when it's put into the wrapper object. This is because Coin is a Sui object type and
      // used only to pass around as Sui objects (such as entry function arguments or objects sent to addresses). For coin balances
      // that need to be embedded in another Sui object struct, use Balance instead because it's not a Sui object type and is much
      // less expensive to use.
      fee: coin::into_balance(fee),
    };

    transfer::transfer(wrapper, service_address);
  }

  /// Where wrapper1 and wrapper2 are two wrapped objects that were sent from different object owners to the service operator.
  /// Both wrapped objects are passed by value because they eventually need to be unpacked.
  public entry fun execute_swap(wrapper1: ObjectWrapper, wrapper2: ObjectWrapper, ctx: &mut TxContext) {
    assert!(wrapper1.to_swap.scarcity == wrapper2.to_swap.scarcity, 0);
    assert!(wrapper1.to_swap.style != wrapper2.to_swap.style, 0);

    // Unpack the two objects to obtain the inner fields, also unwraps the objects:
    let ObjectWrapper {
      id: id1,
      original_owner: original_owner1,
      to_swap: object1,
      fee: fee1,
    } = wrapper1;

    let ObjectWrapper {
      id: id2,
      original_owner: original_owner2,
      to_swap: object2,
      fee: fee2,
    } = wrapper2;

    // perform actual swap
    transfer::transfer(object1, original_owner2);
    transfer::transfer(object2, original_owner1);

    // take the fee
    let service_address = tx_context::sender(ctx);
    balance::join(&mut fee1, fee2);
    transfer::public_transfer(coin::from_balance(fee1, ctx), service_address);

    // Finally, delete both wrapped objects. Remember, UID is not drop so we need to use the following API to drop it
    object::delete(id1);
    object::delete(id2);
  }

  /// #2 Wrapping through Option
  /// 
  /// A warrior with a sword and shield. A warrior might have a sword and shield, or might not have either.
  /// The warrior should be able to add a sword and shield, and replace the current ones at any time. To design this,
  /// define a SimpleWarrior type:
  struct SimpleWarrior has key {
    id: UID,
    sword: Option<Sword>,
    shield: Option<Shield>,
  }
  struct Sword has key, store {
  id: UID,
  strength: u8,
  }

  struct Shield has key, store {
    id: UID,
    armor: u8,
  }

  /// When you create a new warrior, set the sword and shield to none to indicate there is no equipment yet:
  public entry fun create_warrior(ctx: &mut TxContext) {
    let warrior = SimpleWarrior {
      id: object::new(ctx),
      sword: option::none(),
      shield: option::none(),
    };
    transfer::transfer(warrior, tx_context::sender(ctx))
  }

  /// You can then define functions to equip new swords or new shields:
  public entry fun equip_sword(warrior: &mut SimpleWarrior, sword: Sword, ctx: &mut TxContext) {
    // Check whether there is already a sword equipped. If so, remove it out and send it back to the sender.
    if (option::is_some(&warrior.sword)) {
      let old_sword = option::extract(&mut warrior.sword);
      transfer::transfer(old_sword, tx_context::sender(ctx));
    };

    // Note that because Sword is a Sui object type without drop ability, if the warrior already has a sword equipped,
    // the warrior can't drop that sword. If you call option::fill without first checking and taking out the existing sword,
    // an error occurs.
    option::fill(&mut warrior.sword, sword);
  }

  /// #3 Wrapping through vector
  /// 
  /// The concept of wrapping objects in a vector field of another Sui object is very similar to wrapping through Option:
  /// an object can contain 0, 1, or many of the wrapped objects of the same type.
  struct Pet has key, store {
    id: UID,
    cuteness: u64,
  }

  // Wraps a vector of Pet in Farm, and can be accessed only through the Farm object.
  struct Farm has key {
    id: UID,
    pets: vector<Pet>,
  }
}
