#[contract]
mod Orderbook {
    use starknet::get_caller_address;
    use starknet::contract_address_const;
    use starknet::ContractAddress;

    #[constructor]
    fn constructor() {
        
    }

    #[storage]
    struct Storage {
        buys_agg: LegacyMap::<u64, u64>,
        sells_agg: LegacyMap::<u64, u64>,
        buy_orders: LegacyMap::<(ContractAddress, u64), u64>, //first u64 is price, second is quantity.
        sell_orders: LegacyMap::<(ContractAddress, u64), u64>, //first u64 is price, second is quantity.
    }

    #[view]
    fn view_buy_orders_at(price: u64) -> u64 {
        buys_agg::read(price)
    }

    #[view]
    fn view_sell_orders_at(price: u64) -> u64 {
        sells_agg::read(price)
    }

    #[view]
    fn announce_price(price: u64, quantity: u64) {}

    #[external]
    fn submit_buy(price: u64, quantity: u64) {
        let sender = get_caller_address();
        buy_orders::write((sender, price), quantity);
        let quantity_old = buys_agg::read(price);
        let new_quantity = quantity_old + quantity; //have to deal with overflow here

        buys_agg::write(price, new_quantity);
    }

    #[external]
    fn submit_sell(price: u64, quantity: u64) {
        let sender = get_caller_address();
        sell_orders::write((sender, price), quantity);

        let quantity_old = sells_agg::read(price);
        let new_quantity = quantity_old + quantity; //potential overflow

        sells_agg::write(price, new_quantity);
    }

    #[external]
    fn cancel_buy(price: u64) {

    }

    #[external]
    fn cancel_sell(price: u64) {

    }


    //currently portrayed as function, should run periodically
    #[external]
    fn settle() {
        let mut i: u64 = 0;
        loop {
            let result: bool = buys_agg::read(i) >= sells_agg::read(i);
            if result {
                break i;
            }
            i += 1;
        };
        let quantity = sells_agg::read(i);
        announce_price(i, quantity);
    }
}

#[cfg(test)]
mod tests{
    use super::Orderbook;
    use starknet::testing::set_caller_address;
    use starknet::ContractAddress;
    use starknet::contract_address_const;

    #[test]
    #[available_gas(200000000)]
    fn test_buy_submittable() {
        let account = contract_address_const::<1>();
        set_caller_address(account);

        Orderbook::submit_buy(1, 50);

        assert(Orderbook::view_buy_orders_at(1) == 50, 'Not equal');
    }

    #[test]
    #[available_gas(200000000)]
    #[should_panic(expected:('Not equal',))]
        fn test_buy_submittable_fail() {
        let account = contract_address_const::<1>();
        set_caller_address(account);

        Orderbook::submit_buy(5, 50);

        assert(Orderbook::view_buy_orders_at(5) == 49, 'Not equal');
    }
}