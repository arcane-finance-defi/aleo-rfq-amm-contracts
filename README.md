# rfq-aleo-dex 

## Table of Contents

* [rfq-aleo-dex](#rfq-aleo-dex)
   * [About](#about)
   * [Deployment](#deployment)
   * [Live Demo](#live-demo)
   * [Motivation: classic AMMs are poor fit for Aleo](#motivation-classic-amms-are-poor-fit-for-aleo)
   * [What is a Request-For-Quote?](#what-is-a-request-for-quote)
   * [How can an RFQ DEX benefit the Aleo Ecosystem?](#how-can-an-rfq-dex-benefit-the-aleo-ecosystem)
* [Build, deploy and test instructions](#build-deploy-and-test-instructions)
* [Program specification](#program-specification)
   * [Records](#records)
      * [Token](#token)
   * [Structs](#structs)
      * [TokenInfo](#tokeninfo)
      * [Quote](#quote)
      * [Signature](#signature)
      * [Deposit](#deposit)
   * [Mappings](#mappings)
      * [registered_tokens](#registered_tokens)
      * [maker_balances](#maker_balances)
      * [executed_quotes](#executed_quotes)
   * [RFQ Transitions/Functions](#rfq-transitionsfunctions)
      * [add_liquidity](#add_liquidity)
      * [remove_liquidity](#remove_liquidity)
      * [quote_swap](#quote_swap)
      * [verify_signature](#verify_signature)
      * [get_deposit_id](#get_deposit_id)
      * [init_demo_market_maker](#init_demo_market_maker)
   * [Tokens: Transitions/Functions](#tokens-transitionsfunctions)
      * [create_token](#create_token)
      * [mint_private](#mint_private)
      * [init_demo_tokens](#init_demo_tokens)

## About 
Arcane.finance is a decentralized exchange on Aleo that offers two major benefits:

- **Private swaps**. Users swap encrypted `Records` for encrypted `Records`.
- **Zero slippage, no front-running**. Quotes are cryptographically signed so users trade with 100% price certainty.

## Deployment

Program id: [rfq_v000003.aleo](https://explorer.hamp.app/program?id=rfq_v000003.aleo)

Deployment tx id: `at1vr7mt5706yntaf8xgyscer4f7v5fps34nstptum4pmks9g29ssgspxf8hx`

## Live Demo

Live demo is available at https://app.arcane.finance/

Use Private faucet to get some test tokens (1000 tokens max per transaction) and Swap interface to trade them.

Please note that sometimes fetching private records takes time. If it takes longer then 3-5 minutes, please try refreshing a page and/or re-syncing Leo wallet (see "Advanced settings" tab).

## Motivation: classic AMMs and Aleo

Constant function Automated Market Makers (AMMs), such as Uniswap or Curve, are perhaps the most integral part of the traditional DeFi ecosystem.

While having many advantages, AMMs on Aleo cannot fully utilize the core privacy-enabling primitives of Aleo: off chain `transition` functions and encrypted `Records`. Because an AMM needs to know up-to-date pool reserves, most of its code has to be placed in a `finalize` function, which is executed on chain and cannot operate on `Records`. This can fixed by relaxing constraints on price function invariant, but this introduce new challenges e.g. with correct handling of slippage. 

For the Aleo ecosystem to grow and be competitive, its decentralized exchanges need to leverage unique privacy-preserving features of Aleo and off-chain computation. This is why we are building a DEX on an entirely different model called "Request-For-Quote" (RFQ).

## What is a Request-For-Quote?

Request-for-quote (RFQ) is a form of P2P swaps. Our protocol offers users OTC (over-the-counter) desk experience, but automated, private and cryptographically signed.

Here’s traditional how OTC trades work:

1. You ask the seller: “Hey, I want to trade my 10 BTC for USDT.”
2. She responds with an offer: “260,079 USDT. Take it or leave it.”
3. If you like the offer, you execute the trade.

Now imagine that you receive cryptographically signed quotes from several sellers, automatically pick the best deal and can execute the trade immediately if you like it. And all this while remaining private. Sounds good? This is exactly how our RFQ DEX works.

In a nutshell, an AMM pricing function `x*y=k` is now replaced with a cryptographically signed, private quote, which is verified off chain, in a `transition`. The pricing is done off chain but the trade is executed on chain.

Some examples of DeFi projects that use RFQ model are: [Hashflow](https://www.hashflow.com/), [Orbiter Finance](https://www.orbiter.finance/), [Hop](https://hop.exchange/), [Airswap](www.airswap.io) 

## How can an RFQ DEX benefit the Aleo Ecosystem?

While this project is an early stage Proof-of-Concept, it already shows that Aleo enables building privacy-preserving DeFi protocols that have real competitive advantages over existing solutions.

There are other considerations behind our choice of RFQ model on Aleo:

1. Institutional Adoption

RFQ model is rooted in traditional financial markets. The adoption of RFQ mechanics can attract to Aleo more sophisticated, institutional participants, with deep liquidity and diverse assets.

3. Expansion to Other Asset Classes
   
RFQ-based execution engines are extremely flexible and can easily be expanded to accommodate derivatives and other financial instruments.

5. Transformation to Dark Pools
   
Our long term vision includes an extension to RFQ model that would allow for completely trustless, but fully regulated dark pools. This will provide additional liquidity and anonymity for trading large blocks of securities without incurring market impact costs.


# Build, deploy and test instructions

Create a `.env` file with your private key and fee record:

```shell
YOUR_ADDRESS=aleo1...
PRIVATE_KEY=APrivateKey1...
RECORD="{
  owner: aleo1....private,
  microcredits: ...u64.private,
  _nonce: ...group.public
}"
```

Run `source .env` before each command.

To deploy the program run:

```sh
snarkos developer deploy "rfq_v000003.aleo" --private-key "${PRIVATE_KEY}" --query "https://vm.aleo.org/api" --path "./build/" --broadcast "https://vm.aleo.org/api/testnet3/transaction/broadcast" --fee 1000 --record "${RECORD}"

```

To initialize demo tokens run with ids 1,2,3 and 4:

```sh
snarkos developer execute "rfq_v000003.aleo" "init_demo_tokens" "1field"  --private-key "${PRIVATE_KEY}" --query "https://vm.aleo.org/api" --broadcast "https://vm.aleo.org/api/testnet3/transaction/broadcast" --fee 1000 --record "${RECORD}"
```

Test tokens correspond to following real assets:

| Token ID | Token             |
| -------- | ----------------- |
| 1        | Tether USD (USDT) |
| 2        | Cicle USD (USDC)  |
| 3        | Bitcoin (BTC)     |
| 4        | Ethereum (ETH)    |

To simplify testing, all test tokens have 6 decimals.

To initalize demoe a market maker run:

```sh
snarkos developer execute "rfq_v000003.aleo" "init_demo_market_maker" "1field"  --private-key "${PRIVATE_KEY}" --query "https://vm.aleo.org/api" --broadcast "https://vm.aleo.org/api/testnet3/transaction/broadcast" --fee 1000 --record "${RECORD}"
```

To mint test tokens with id 1 (USDT) run:

```sh
snarkos developer execute "rfq_v000003.aleo" "mint_private" "${YOUR_ADDRESS}" "1u64" "1000000000u128" --private-key "${PRIVATE_KEY}" --query "https://vm.aleo.org/api" --broadcast "https://vm.aleo.org/api/testnet3/transaction/broadcast" --fee 1000 --record "${RECORD}"

```

To execute a swap run:

```sh
snarkos developer execute "rfq_v000003.aleo" "quote_swap" "{TOKEN}" "{QUOTE}" "{SIGNATURE}" --private-key "${PRIVATE_KEY}" --query "https://vm.aleo.org/api" --broadcast "https://vm.aleo.org/api/testnet3/transaction/broadcast" --fee 1000 --record "${RECORD}"
```

where:

- `{TOKEN}` is a record returned by `mint_private`
- `{QUOTE}` and `{SIGNATURE}` can be obtained by sending a GET query request to our market maker with the following format:

```ssh
https://ftoy1oiyo6.execute-api.us-east-1.amazonaws.com/default/leoswap-maker?amount_in=<AMOUNT>&token_in=<TOKEN_YOU_SELL>&token_out=<TOKEN_YOU_BUY>
```

where
- `<AMOUNT>` should be the amount you want to sell (all test tokens are fixed point integer with 6 decimals)
- `<TOKEN_YOU_SELL>` the id of the token you sell, i.e. the id of the `{TOKEN}`
- `<TOKEN_YOU_BUY>` the id of the token you want to buy.

For example, to get a quote for a swap of 1000 USDT for ETH, request:

```
https://ftoy1oiyo6.execute-api.us-east-1.amazonaws.com/default/leoswap-maker?amount_in=1000000000&token_in=1&token_out=4
```

It will return a json with a quote and a signature:

```json
{
  "signature": "{challenge:134761902584291722445245311261060722474143214429316094887383208318845166464scalar,response:1174910261812754497995625895072005505083850262557116981170653056543943978848scalar,pk_sig:3281664209406841603541028760915163024036467969430202533099724532705308889105group,pr_sig:5539506505093814818821647255067173289296108627180178059588713937273990243414group,sk_prf:51394841380773997286630059211554203011051867539942123398656527573489016493scalar}",
  "quote": "{amount_in:1000000000u128,amount_out:594132u128,token_in:1u64,token_out:4u64,maker_address:aleo1r3qlsxnuux6rkrhk24rktdtzu7kjr3c2fw5fvtp6a9dwghe0xgzs9c2nhu,nonce:264473671193890215536616807758839040807335648385338432938227630636884179618field,valid_until:999999u32}"
}
```

This means you will get 0.594132 ETH for 1000 USDT.

# Program specification

This section provides a detailed description of all elements of the main Aleo program.

## Records

### Token

`Token` record stores tradeable, fungible tokens.

```rust
record Token {
    owner: address,
    amount: u128,
    token_id: u64,
}
```

Record fields:

| Name       | Type      | Description                                                 |
| ---------- | --------- | ----------------------------------------------------------- |
| `owner`    | `address` | token owner's address                                       |
| `amount`   | `u128`    | amount stored in a records                                  |
| `token_id` | `u64`     | a unique id to distinguish between different kinds of token |

#### Comments

Our program operates on test tokens that are defined in the same program because Aleo currently doesn't have a common token standard and primitives required to build one are missing (e.g. `self.parent` proposed here https://github.com/AleoHQ/ARCs/tree/master/arc-0030). Our team is working on relevant ARCs.

## Structs

### TokenInfo

`TokenInfo` defines the basic properties of a token.

```rust
struct TokenInfo {
    token_id: u64,
    max_supply: u128,
    decimals: u8,
}
```

Struct fields:

| Name         | Type      | Description                                  |
| ------------ | --------- | -------------------------------------------- |
| `token_id`   | `address` | a unique token identifier                    |
| `max_supply` | `u128`    | supply cap                                   |
| `decimals`   | `u8`      | fixed point decimals in this token's amounts |

### Quote

`Quote` contains the maker's quote information. A `Quote` with a valid `Signature` is a commitment of a maker (seller) to enter a swap.

```rust
struct Quote {
    amount_in: u128,
    amount_out: u128,
    token_in: u64,
    token_out: u64,
    maker_address: address,
    nonce: field,
    valid_until: u32,
}
```

Struct fields:

| Name            | Type      | Description                                              |
| --------------- | --------- | -------------------------------------------------------- |
| `amount_in`     | `u128`    | amount of tokens a user wants to swap                    |
| `amount_out`    | `u128`    | amount of tokens a maker offers for `amount_in`          |
| `token_in`      | `u64`     | id of the token users wants to sell                      |
| `token_out`     | `u64`     | id of the token users wants to buy                       |
| `maker_address` | `address` | address of maker (seller)                                |
| `nonce`         | `field`   | random/semi-random number that a maker can use just once |
| `valid_until`   | `u32`     | block number the quote is valid until                    |

#### Comments

- Quote is private for a user (buyer): it does not include any user information.
- Quote is pseudo private for a maker (seller): a maker can use several unrelated values for `maker_address`
- `nonce` is used to prevent replay attacks, i.e. using the same quote in more than one trade.
- `valid_until` limits the commitment of a maker to enter a swap up until a certain block. More accurate time constraints will be introduced as Leo `finalize` functions will be able to access current time information.

### Signature

`Signature` is a Schnorr signature that is used to verify a quote.

```rust
struct Signature {
    challenge: scalar,
    response: scalar,
    pk_sig: group,
    pr_sig: group,
    sk_prf: scalar,
}
```

Struct fields:

`Signature` has the same fields as https://github.com/AleoHQ/snarkVM/blob/f2eda3eb2f2b3d469d67df8b45019b59904be10e/console/account/src/signature/mod.rs#L33. `pk_sig`, `pr_sig` and `sk_prf` represent Compute Key, see https://github.com/AleoHQ/snarkVM/blob/f2eda3eb2f2b3d469d67df8b45019b59904be10e/circuit/account/src/compute_key/mod.rs#L25.

#### Comments

Leo will soon have a native signature verification op code, see PR https://github.com/AleoHQ/leo/pull/2519. It will replace our custom signature implementation when released.

### Deposit
`Deposit` is a struct that packs maker's address and token id, so that they can be hashed together to form a unique deposit id.

```rust
struct Deposit {
    maker_address: address,
    token_id: u64,
}
```

Struct fields:
| Name            | Type      | Description                                              |
| --------------- | --------- | -------------------------------------------------------- |
| `maker_address`     | `address`    | address of maker (seller)                    |
| `token_id`    | `u64`    | id of the token that maker deposits to trade          |


## Mappings

This section describes the public, on chain state of the main program.

### registered_tokens

`registered_tokens` tracks which internal tokens have been created.

```rust
mapping registered_tokens: u64 => TokenInfo;
```

| Key           | Value                                |
| ------------- | ------------------------------------ |
| Id of a token | `TokenInfo` that describes the token |

### maker_balances

`maker_balance` keeps track of reserves of makers. These reserves guarantee execution of valid quotes.

```rust
mapping maker_balances: field  => u128;
```

| Key                                    | Value                    |
| -------------------------------------- | ------------------------ |
| hash(maker's address) + hash(token_id) | amount of token reserves |

#### Comments

A key in `maker_balance` is a sum of hashes of the maker's address and an id of a token reserved. This allows a maker to create several pseudo-anonymous reserve buckets using different addresses.

### executed_quotes

`executed_quotes` is used to prevent using the same `Quote` more than once.

```rust
mapping executed_quotes: field  => u32;
```

| Key           | Value                               |
| ------------- | ----------------------------------- |
| hash(`Quote`) | block in which `Quote` was executed |

#### Comments

A maker should use a different `nonce` in every new quote, regardless of whether it has been executed or not. For example, it can be achieved by picking random or monotonically increasing nonces.

## RFQ Transitions/Functions

Below is the description of functions and transitions related to RFQ swaps.

### add_liquidity

A maker executes `add_liquidity` to provide token reserves that will be used to execute swaps she quoted.

```rust
transition add_liquidity(t: Token, maker_address: address, amount: u128) -> Token
```

Parameters:

| Parameter                | Description                    |
| ------------------------ | ------------------------------ |
| `t: Token`               | token record                   |
| `maker_address: address` | signing address of a maker     |
| `amount: u128`           | amount of liquidity to reserve |

Returns: a "change" `Token` if the amount of liquidity to reserve is less than the amount stored in the `Token` record `t`.

#### Comments

A maker can use different signing addresses to provide liquidity for the same token. This allows her to have "buckets" of liquidity that do not reveal information on which token she is going to trade, only the amount, i.e. `finalize` for this transition reveals neither maker's address nor token id:

```
finalize add_liquidity(deposit_id: field, amount: u128)
```

Finalize only makes public the `amount` and `deposit_id`, which is calculated off chain as:

```rust
let deposit_id: field = Poseidon8::hash_to_field(
    Deposit {
        maker_address,
        token_id: t.token_id
    }
);
```

and thus conceal `token_id` because `maker_address` can by any address controlled by the maker.

This means that before the maker signs and sends the first quote using this `maker_address`, it is impossible to know that a certain amount of a particular token has been deposited to the DEX.

### remove_liquidity

`remove_liquidity` withdraws maker's reservers from the exchange. Must be called using the same address that was passed as a parameter while depositing tokens using `add_liquidity`

```rust
transition remove_liquidity(token_id: u64, amount: u128) -> Token
```

Parameters:

| Parameter       | Description            |
| --------------- | ---------------------- |
| `token_id: u64` | token to be withdrawn  |
| `amount: u128`  | amount to be withdrawn |

Returns: a private `Token` record if there are enough tokens to withdraw.

Similar to `add_liquidity`, `remove_liquidity` by itself does not make public which token is withdrawn and which address is the owner.

#### Comments

Note that due to the private nature of swaps, a maker can always withdraw her deposit via executing a swap against her own quote. The `remove_liquidity` transition is just a more convenient way to do it.

### quote_swap

`quote_swap` is the transition that performs swap of a given `Token` record `t`, by verifying a signature `s` of a maker's quote `q`.

```rust
transition quote_swap(
    t: Token,
    q: Quote,
    s: Signature
) -> (Token, Token, Token)
```

Parameters:

| Parameter      | Description                   |
| -------------- | ----------------------------- |
| `t: Token`     | token record to be swapped    |
| `q: Quote`     | maker's quote                 |
| `s: Signature` | signature to verify quote `q` |

The transition returns three token records:

1. record with tokens bought by a user (owner: user)
2. record with the "change" remaining from `t` (owner: user)
3. record with tokens sold by a user (owner: maker)

The `finalize` function makes public only the following fields:

```rust
finalize quote_swap(
    withdraw_from: field, // deposit id
    quote_hash: field,    // hash of a quote
    amount_out: u128,     // amount of tokens bought
    valid_until: u32      // expiry block of a quote
)
```

The following information remains entirely private:

- What token has a user sold
- How many tokens has a user sold
- At what price was the trade executed

### verify_signature

This function uses a modified Schnorr signature algorithm from snarkVM to validate a `Signature` of a quote.

```rust
function verify_signature(q: Quote, s: Signature) -> bool
```

| Parameter      | Description           |
| -------------- | --------------------- |
| `q: Quote`     | a signed quote        |
| `s: Signature` | a signature to verify |

Returns: `true` if a signature is valid and `maker_address` in a quote is the signer, else returns `false`.

#### Comments

The signing and verification algorithms are modified versions of the algorithms found in snarVM (see, https://github.com/AleoHQ/snarkVM/blob/f2eda3eb2f2b3d469d67df8b45019b59904be10e/console/account/src/signature/verify.rs). There are two major differences:

- Rather than using `g_scalar_multiply` with 251 generators, we had to use only the first generator of `GENERATOR_G`. Initially, we used all generators, but the size of a proving key for `quote_swap` was 4.6GB (see program with id [leoswapxyz_v000004.aleo](https://explorer.hamp.app/program?id=leoswapxyz_v000004.aleo)). But because WASM32 only supports 4GB, no wallet could execute this transition.
- Because there are no arrays, we had to sum hashes of individual values instead of hashing `(r * G, pk_sig, pr_sig, address, message)` at once. This can decrease cryptographic security of the signature. A better choice would be to pack these values in a `struct` and hash it in a single operation, but we decided to leave it as is and wait until proper hash verification is introduced to Leo.

### get_deposit_id

`get_deposit_id` is a helper function that hashes the maker's address and token id to get a deposit bucket id.

```rust
function get_deposit_id(maker_address: address, token_id: u64) -> field
```

Parameters:

| Parameter                | Description                   |
| ------------------------ | ----------------------------- |
| `maker_address: address` | maker's address               |
| `token_id: u64`          | id of a token to be deposited |

Returns a field element that uniquely identifies a deposit.

### init_demo_market_maker

`init_demo_market_maker` is an auxiliary configuration function that simplifies testing by providing 1M test token liquidity for each demo tokens with ids 1,2,3 and 4 for a test market maker with an address `aleo1r3qlsxnuux6rkrhk24rktdtzu7kjr3c2fw5fvtp6a9dwghe0xgzs9c2nhu`.

```rust
transition init_demo_market_maker(dummy: field) -> field
```

Parameters:

| Parameter      | Description                  |
| -------------- | ---------------------------- |
| `dummy: field` | any value, see comment below |

Returns a `dummy` value plus one.

#### Comments

This transition does not requireany input parameters or return values. Dummy parameter and output value are used only as a workaround for https://github.com/AleoHQ/snarkOS/issues/2510

## Tokens: Transitions/Functions

Our program uses internal tokens.For the sake of brevity, it implements only the required minimum of token-related functions.

### create_token

`create_token` transition registers a new internal token.

```rust
transition create_token(token_id: u64, decimals: u8, max_supply: u128)
```

Parameters:

| Parameter          | Description                  |
| ------------------ | ---------------------------- |
| `token_id: u64`    | id of a new token            |
| `decimals: u8`     | the number of decimal digits |
| `max_supply: u128` | maximum supply               |

Result: a new token is registered and the `registered_tokens` map is updated.

### mint_private

`mint_private` transition performs a private mint

```rust
transition mint_private(
    receiver: address,
    token_id: u64,
    amount: u128,
) -> Token
```

Parameters:

| Parameter           | Description                |
| ------------------- | -------------------------- |
| `receiver: address` | owner of the minted tokens |
| `token_id: u64`     | token to mint              |
| `amount: u128`      | amount to mint             |

Result: a new `Token` record is created with the specified amount and an owner set to be the `receiver`

#### Comments

Each call of `mint_private` can mint at most 1000 tokens (assuming 6 decimals) to prevent depletion of demo maker resources.

### init_demo_tokens

`init_demo_tokens` is an auxiliary configuration function that simplifies testing. Running `init_demo_tokens` configures 4 test tokens with 6 decimals in one transaction.

```rust
transition init_demo_tokens(dummy: field) -> field
```

Parameters:

| Parameter      | Description                  |
| -------------- | ---------------------------- |
| `dummy: field` | any value, see comment below |

Result: a `dummy` value plus one

#### Comments

Similar to `init_demo_market_maker` , dummy parameters are used only as a workaround.


