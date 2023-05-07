/// In Sui, everything is an NFT - Objects are unique, non-fungible and owned. So technically, a simple type publishing is enough.
/// However, there are some attempts to create NFT standards"
/// 1. SUI Collectible https://github.com/MystenLabs/sui/blob/b197bee53d73c1aff8843e759c23c166793153a3/crates/sui-framework/sources/collectible.move
/// 2. https://capsulecraft.dev/
/// 3. https://github.com/Origin-Byte/nft-protocol
module examples::nft {
  use sui::url::{Self, Url};
  use std::string::{Self, String};
  use sui::object::{Self, ID, UID};
  use sui::event;
  use sui::transfer;
  use sui::tx_context::{Self, TxContext};

  struct Nft has key, store {
    id: UID,
    name: String,
    description: String,
    uri: Url,
  }

  struct NftMintedEvent has copy, drop {
    object_id: ID,
    creator: address,
    name: String,
  }

  public fun name(nft: &Nft): &String {
    &nft.name
  }

  public fun description(nft: &Nft): &String {
    &nft.description
  }

  public fun uri(nft: &Nft): &Url {
    &nft.uri
  }

  fun new_nft(
    name: vector<u8>,
    description: vector<u8>,
    uri: vector<u8>,
    ctx: &mut TxContext
  ): Nft {
    Nft {
      id: object::new(ctx),
      name: string::utf8(name),
      description: string::utf8(description),
      uri: url::new_unsafe_from_bytes(uri),
    }
  }

  entry public fun mint_to_sender(
    name: vector<u8>,
    description: vector<u8>,
    uri: vector<u8>,
    ctx: &mut TxContext
  ) {
    let sender = tx_context::sender(ctx);
    let nft = new_nft(name, description, uri, ctx);

    event::emit(NftMintedEvent {
      object_id: object::id(&nft),
      creator: sender,
      name: nft.name,
    });

    transfer::transfer(nft, sender);
  }

  entry public fun transfer(nft: Nft, recipient: address) {
    transfer::transfer(nft, recipient);
  }

  public entry fun update_description(nft: &mut Nft, description: vector<u8>) {
    nft.description = string::utf8(description)
  }

  public entry fun butn(nft: Nft) {
    let Nft {id, name: _, description: _, uri: _} = nft;
    object::delete(id);
  }
}
