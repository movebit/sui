// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// A storable handler for Balances in general. Is used in the `Coin`
/// module to allow balance operations and can be used to implement
/// custom coins with `Supply` and `Balance`s.
module sui::balance {
    friend sui::sui_system;

    /// For when trying to destroy a non-zero balance.
    const ENonZero: u64 = 0;

    /// For when an overflow is happening on Supply operations.
    const EOverflow: u64 = 1;

    /// For when trying to withdraw more than there is.
    const ENotEnough: u64 = 2;

    /// A Supply of T. Used for minting and burning.
    /// Wrapped into a `TreasuryCap` in the `Coin` module.
    struct Supply<phantom T> has store {
        value: u64
    }

    /// Storable balance - an inner struct of a Coin type.
    /// Can be used to store coins which don't need the key ability.
    struct Balance<phantom T> has store {
        value: u64
    }

    /// Get the amount stored in a `Balance`.
    public fun value<T>(self: &Balance<T>): u64 {
        self.value
    }

    /// Get the `Supply` value.
    public fun supply_value<T>(supply: &Supply<T>): u64 {
        supply.value
    }

    /// Create a new supply for type T.
    public fun create_supply<T: drop>(_: T): Supply<T> {
        Supply { value: 0 }
    }

    /// Increase supply by `value` and create a new `Balance<T>` with this value.
    public fun increase_supply<T>(self: &mut Supply<T>, value: u64): Balance<T> {
        assert!(value < (18446744073709551615u64 - self.value), EOverflow);
        self.value = self.value + value;
        Balance { value }
    }

    spec increase_supply {
        aborts_if value >= (MAX_U64 - self.value) with EOverflow;
        ensures result.value == value;
    }

    /// Burn a Balance<T> and decrease Supply<T>.
    public fun decrease_supply<T>(self: &mut Supply<T>, balance: Balance<T>): u64 {
        let Balance { value } = balance;
        assert!(self.value >= value, EOverflow);
        self.value = self.value - value;
        value
    }

    spec decrease_supply {
        let value = balance.value;
        aborts_if self.value < value with EOverflow;

        ensures result == balance.value;
        ensures result == old(self.value) - self.value;
    }

    /// Create a zero `Balance` for type `T`.
    public fun zero<T>(): Balance<T> {
        Balance { value: 0 }
    }

    spec zero {
        aborts_if false;
        ensures result.value == 0;
    }

    /// Join two balances together.
    public fun join<T>(self: &mut Balance<T>, balance: Balance<T>): u64 {
        let Balance { value } = balance;
        self.value = self.value + value;
        self.value
    }

    spec join {
        aborts_if self.value + balance.value > MAX_U64;
        ensures self.value == old(self.value) + balance.value;
        ensures result == self.value;
    }

    /// Split a `Balance` and take a sub balance from it.
    public fun split<T>(self: &mut Balance<T>, value: u64): Balance<T> {
        assert!(self.value >= value, ENotEnough);
        self.value = self.value - value;
        Balance { value }
    }

    spec split {
        aborts_if self.value < value with ENotEnough;
        ensures self.value == old(self.value) - value;
        ensures result.value == value;
    }

    /// Destroy a zero `Balance`.
    public fun destroy_zero<T>(balance: Balance<T>) {
        assert!(balance.value == 0, ENonZero);
        let Balance { value: _ } = balance;
    }

    spec destroy_zero {
        aborts_if balance.value != 0 with ENonZero;
    }

    /// CAUTION: this function creates a `Balance` without increasing the supply.
    /// It should only be called by `sui_system::advance_epoch` to create staking rewards,
    /// and nowhere else.
    public(friend) fun create_staking_rewards<T>(value: u64): Balance<T> {
        Balance { value }
    }

    /// CAUTION: this function destroys a `Balance` without decreasing the supply.
    /// It should only be called by `sui_system::advance_epoch` to destroy storage rebates,
    /// and nowhere else.
    public(friend) fun destroy_storage_rebates<T>(self: Balance<T>) {
        let Balance { value: _ } = self;
    }

    #[test_only]
    /// Create a `Balance` of any coin for testing purposes.
    public fun create_for_testing<T>(value: u64): Balance<T> {
        Balance { value }
    }

    #[test_only]
    /// Destroy a `Balance` with any value in it for testing purposes.
    public fun destroy_for_testing<T>(self: Balance<T>): u64 {
        let Balance { value } = self;
        value
    }

    #[test_only]
    /// Destroy a `Supply` with any value in it for testing purposes.
    public fun destroy_supply_for_testing<T>(self: Supply<T>): u64 {
        let Supply { value } = self;
        value
    }

    #[test_only]
    /// Create a `Supply` of any coin for testing purposes.
    public fun create_supply_for_testing<T>(value: u64): Supply<T> {
        Supply { value }
    }
}

#[test_only]
module sui::balance_tests {
    use sui::balance;
    use sui::sui::SUI;

    #[test]
    fun test_balance() {
        let balance = balance::zero<SUI>();
        let another = balance::create_for_testing(1000);

        balance::join(&mut balance, another);

        assert!(balance::value(&balance) == 1000, 0);

        let balance1 = balance::split(&mut balance, 333);
        let balance2 = balance::split(&mut balance, 333);
        let balance3 = balance::split(&mut balance, 334);

        balance::destroy_zero(balance);

        assert!(balance::value(&balance1) == 333, 1);
        assert!(balance::value(&balance2) == 333, 2);
        assert!(balance::value(&balance3) == 334, 3);

        balance::destroy_for_testing(balance1);
        balance::destroy_for_testing(balance2);
        balance::destroy_for_testing(balance3);
    }
}
