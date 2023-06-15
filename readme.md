# Double Auction - Cairo
A small double auction PoC that serves as a playground to better learn Cairo.

## Why?
I already know Periodic Double Auctions from my master thesis and using smart contracts was actually an initial idea. I also wanted to learn Cairo and after reading the Cairo101 book, it was time to try it out on a non-fibonacci/non-hello world example.

## How?
The smart contract simulates the role of the auctioneer in a periodic double auction. The smart contract gets deployed with a maximum price. Buyers and sellers can then submit the order, which consist of multiple quantity price pairs. Depending on whether a trader wants to buy or sell, the trader will use `submit_buy` or `submit_sell`. The smart contract will check the order for correctness and aggregate them to the overall demand and supply.

At a specific point in time, the settle function will be called, to settle the auction. This will find the highest price for which demand exceeds supply to find the market-clearing price. 

## Future Work
- Use ERC20.cairo to actually allow the auctioneer to transfer goods
- Fix the functionality to check that the buy quantities are descending and supply quantities are ascending for ascending prices.
- Look into settle functionality again.