/// Collection types protect against accidental deletion when they might not be empty.
/// This protection comes from the fact that they do not have drop, so must be explicitly deleted, using this API
/// 
/// The types and function discussed in this section are built into the Sui framework in modules table and bag.
/// As with dynamic fields, there is also an object_ variant of both: ObjectTable in object_table and ObjectBag in object_bag. 
/// The relationship between Table and ObjectTable, and Bag and ObjectBag are the same as between a field and an object
/// field: The former can hold any store type as a value, but objects stored as values are hidden when viewed from external 
/// storage. The latter can only store objects as values, but keeps those objects visible at their ID in external storage.
/// 
/// 1. Table<K, V> is a homogeneous map, meaning that all its keys have the same type as each other (K), and all
///    its values have the same type as each other as well (V). It is created with sui::table::new, which requires access to a 
///    &mut TxContext because Tables are objects themselves, which can be transferred, shared, wrapped, or unwrapped, 
///    just like any other object.
/// 2. Bag is a heterogeneous map, so it can hold key-value pairs of arbitrary types (they don't need to match each other).
///    Note that the Bag type does not have any type parameters for this reason. Like Table, Bag is also an object, so creating
///    one with sui::bag::new requires supplying a &mut TxContext to generate an ID.
module examples::collection {
}
