#[contract]
mod Orderbook {
    use starknet::get_caller_address;
    use starknet::contract_address_const;
    use starknet::ContractAddress;
    use array::ArrayTrait;
    use clone::Clone;
    use debug::PrintTrait;


    #[derive(Drop, Serde, Copy, PartialEq)]
    struct QuantityPricePair {
        quantity: u64,
        price: u64,
    }

    #[storage]
    struct Storage {
        max_price: u64,
        buys_agg: LegacyMap::<u64, u64>,
        sells_agg: LegacyMap::<u64, u64>,
        buy_orders: LegacyMap::<(ContractAddress, u64),
        u64>, //first u64 is price, second is quantity.
        sell_orders: LegacyMap::<(ContractAddress, u64),
        u64>, //first u64 is price, second is quantity.
    }

    #[constructor]
    fn constructor(_max_price: u64) {
        max_price::write(_max_price);
    }

    #[view]
    fn view_buy_orders_at(price: u64) -> u64 {
        buys_agg::read(price)
    }

    #[view]
    fn view_sell_orders_at(price: u64) -> u64 {
        sells_agg::read(price)
    }

    #[event]
    fn announce_price(market_clearing_price: QuantityPricePair) {}

    #[external]
    fn submit_buy(order: Array<QuantityPricePair>) {
        let length_order = order.clone().len();

        if length_order == 0 {
            return ();
        }

        assert(order.at(length_order - 1).price.clone() == max_price::read(), 'Need max price');

        //need to verify that buy orders are descending in quantity and sell orders ascending as price INCREASES.
        let mut i = 0;

        if length_order != 1 {
            loop {
                if i == length_order - 2 {
                    break ();
                }
                //commented out since it currently does not work.
                //assert(order.at(i).quantity.clone() >= order.at(i + 1).quantity.clone(), 'Order formatted wrong');
                //assert(*order.clone().at(i).price < *order.clone().at(i + 1).price, 'Order formatted wrong');
                i += 1;
            }
        }

        let sender = get_caller_address();
        let mut cur_price = 0;
        let mut selector = 0;

        loop {
            if selector < length_order - 1 { //ensure that selector did not reach the end already.
                if *order.at(selector).price < cur_price {
                    selector += 1;
                }
            }

            let quantity = *order.at(selector).quantity;
            buy_orders::write((sender, cur_price), quantity);
            let quantity_old = buys_agg::read(cur_price);
            let new_quantity = quantity_old + quantity; //have to deal with overflow here

            buys_agg::write(cur_price, new_quantity);

            if cur_price == max_price::read() {
                break ();
            }
            cur_price += 1;
        }
    }

    #[external]
    fn submit_sell(order: Array<QuantityPricePair>) {
        let length_order = order.clone().len();

        if length_order == 0 {
            return ();
        }

        assert(*order.at(0).price == 0, 'Need min price');
        //need to verify that buy orders are descending in quantity and sell orders ascending as price INCREASES.
        let mut i = 0;

        if length_order != 1 {
            loop {
                if i == length_order - 2 {
                    break ();
                }
                //assert(order.at(i).quantity.clone() <= order.at(i + 1).quantity.clone(), 'Order formatted wrong');
                //assert(*order.clone().at(i).price < *order.clone().at(i + 1).price, 'Order formatted wrong');
                i += 1;
            }
        }

        let sender = get_caller_address();

        let mut cur_price = 0;
        let mut selector = 0;
        loop {
            if selector < length_order - 1 {
                if *order.at(selector + 1).price <= cur_price {
                    selector += 1;
                }
            }
            let quantity = *order.at(selector).quantity;
            sell_orders::write((sender, cur_price), quantity);
            let quantity_old = sells_agg::read(cur_price);
            let new_quantity = quantity_old + quantity; //have to deal with overflow here

            sells_agg::write(cur_price, new_quantity);

            if cur_price == max_price::read() {
                break ();
            }
            cur_price += 1;
        }
    }

    //Retrieve the buy at the price that was made previously, and cancel it by setting it to 0 again.
    #[external]
    fn cancel_buy(price: u64) {
        let sender = get_caller_address();

        let quantity = buy_orders::read((sender, price));
        let quantity_agg = buys_agg::read(price);

        buys_agg::write(price, quantity_agg - quantity);
        buy_orders::write((sender, price), 0);
    }

    #[external]
    fn cancel_sell(price: u64) {
        let sender = get_caller_address();

        let quantity = sell_orders::read((sender, price));
        let quantity_agg = sells_agg::read(price);

        sells_agg::write(price, quantity_agg - quantity);
        sell_orders::write((sender, price), 0);
    }

    //currently portrayed as function, should run periodically
    #[external]
    fn settle() -> QuantityPricePair {
        let mut i: u64 = 0;
        let mcp = loop {
            let mcp_found: bool = buys_agg::read(i) <= sells_agg::read(i);
            if mcp_found {
                break i - 1;
            }
            i += 1;
        };
        let quantity = sells_agg::read(mcp);

        let mcp = QuantityPricePair { quantity: quantity, price: mcp };

        announce_price(mcp);

        mcp
    }
}

#[cfg(test)]
mod tests {
    use super::Orderbook;
    use starknet::testing::set_caller_address;
    use starknet::ContractAddress;
    use starknet::contract_address_const;
    use array::ArrayTrait;
    use debug::PrintTrait;

    #[test]
    #[available_gas(200000000)]
    fn test_buy_submittable() {
        Orderbook::constructor(5);
        let account = contract_address_const::<1>();
        set_caller_address(account);

        let mut order = ArrayTrait::new();
        order.append(Orderbook::QuantityPricePair { quantity: 150, price: 0 });
        order.append(Orderbook::QuantityPricePair { quantity: 100, price: 3 });
        order.append(Orderbook::QuantityPricePair { quantity: 50, price: 5 });

        Orderbook::submit_buy(order);
        assert(Orderbook::view_buy_orders_at(0) == 150, 'Submission of buy failed1');
        assert(Orderbook::view_buy_orders_at(1) == 100, 'Submission of buy failed2');
        assert(Orderbook::view_buy_orders_at(2) == 100, 'Submission of buy failed3');
        assert(Orderbook::view_buy_orders_at(3) == 100, 'Submission of buy failed4');
        assert(Orderbook::view_buy_orders_at(4) == 50, 'Submission of buy failed5');
        assert(Orderbook::view_buy_orders_at(5) == 50, 'Submission of buy failed6');
    }

    #[test]
    #[available_gas(200000000)]
    #[should_panic(expected: ('Submission of buy failed', ))]
    fn test_buy_submittable_fail() {
        Orderbook::constructor(5);
        let account = contract_address_const::<1>();
        set_caller_address(account);

        let mut order = ArrayTrait::new();
        order.append(Orderbook::QuantityPricePair { quantity: 50, price: 5 });

        Orderbook::submit_buy(order);

        assert(Orderbook::view_buy_orders_at(5) == 49, 'Submission of buy failed');
    }

    #[test]
    #[available_gas(2000000000)]
    fn settle_test() {
        Orderbook::constructor(5);
        let account = contract_address_const::<1>();
        set_caller_address(account);

        let mut order = ArrayTrait::new();
        order.append(Orderbook::QuantityPricePair { quantity: 100, price: 0 });
        order.append(Orderbook::QuantityPricePair { quantity: 50, price: 3 });
        order.append(Orderbook::QuantityPricePair { quantity: 10, price: 5 });

        Orderbook::submit_buy(order);

        assert(Orderbook::view_buy_orders_at(0) == 100, 'Submission of buy failed12');
        assert(Orderbook::view_buy_orders_at(1) == 50, 'Submission of buy failed2');
        assert(Orderbook::view_buy_orders_at(2) == 50, 'Submission of buy failed3');
        assert(Orderbook::view_buy_orders_at(3) == 50, 'Submission of buy failed4');
        assert(Orderbook::view_buy_orders_at(4) == 10, 'Submission of buy failed5');
        assert(Orderbook::view_buy_orders_at(5) == 10, 'Submission of buy failed6');

        let mut order_sell = ArrayTrait::new();
        order_sell.append(Orderbook::QuantityPricePair { quantity: 10, price: 0 });
        order_sell.append(Orderbook::QuantityPricePair { quantity: 20, price: 2 });
        order_sell.append(Orderbook::QuantityPricePair { quantity: 50, price: 5 });

        Orderbook::submit_sell(order_sell);

        assert(Orderbook::view_sell_orders_at(0) == 10, 'Submission of sell failed1');
        assert(Orderbook::view_sell_orders_at(1) == 10, 'Submission of sell failed2');
        assert(Orderbook::view_sell_orders_at(2) == 20, 'Submission of sell failed3');
        assert(Orderbook::view_sell_orders_at(3) == 20, 'Submission of sell failed4');
        assert(Orderbook::view_sell_orders_at(4) == 20, 'Submission of sell failed5');
        assert(Orderbook::view_sell_orders_at(5) == 50, 'Submission of sell failed6');

        let result = Orderbook::settle();

        let expected_result = Orderbook::QuantityPricePair { quantity: 20, price: 3 };

        assert(result == expected_result, 'Wrong MCP');
    }
}
