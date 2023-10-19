program arcane_rfq_amm_v000001.aleo {

    // ██████████████████████████████████████████████████████████████████████
    //                                 Tokens
    // ██████████████████████████████████████████████████████████████████████

    record Token {
        owner: address,
        amount: u128,
        token_id: u64,
    }

    struct TokenInfo {
        token_id: u64,        
        max_supply: u128,
        decimals: u8,
    }

    mapping registered_tokens: u64 => TokenInfo;

    transition create_token(token_id: u64, decimals: u8, max_supply: u128) {
        let new_token: TokenInfo = TokenInfo{
            token_id,
            decimals,
            max_supply,
        };
        return then finalize(new_token);
    }

    finalize create_token(new_token: TokenInfo) {
        assert(!Mapping::contains(registered_tokens, new_token.token_id));
        Mapping::set(registered_tokens, new_token.token_id, new_token);    
    }

    transition mint_private(
        receiver: address, 
        token_id: u64, 
        amount: u128,
    ) -> Token {
        assert(amount <= 1000u128 * (10u128 ** 6u8));
        return Token {
            owner: receiver,
            amount: amount,
            token_id,
        } then finalize(token_id);        
    }

    finalize mint_private(token_id: u64) {
        let token_info: TokenInfo = Mapping::get(registered_tokens, token_id);
    }

    /// ██████████████████████████████████████████████████████████████████████
    ///                             Private AMM Swaps 
    /// ██████████████████████████████████████████████████████████████████████
    
    ///  Pools
    struct PoolKey {
        token1: u64,
        token2: u64,
    }

    record PoolAdmin {
        owner: address,
        pool_key: field
    }

    struct PoolInfo {
        id: field, // hash(token1.id, token2.id)
        token1_id: u64,
        token2_id: u64,
        reserve1: u128,
        reserve2: u128,
        lp_total_supply: u128,
        swap_fee: u128, // 10000 based, 1 = 0.01% = 0.0001
    }

    struct DepositKey {
        holder: address,
        pool_key: field,
        deposit_id: field,
    }

    record LpTokenReceipt {
        owner: address,
        token1_id: u64,
        token2_id: u64,
        deposit_id: field
    }

    ///  Extra amount
    struct ExtraAmountKey {
        voucher: field,
        token_id: u64,
    }

    struct ExtraAmount {
        token_id: u64,
        token_amount: u128,
    }

    record ExtraAmountVoucher {
        owner: address,
        token_id: u64,
        voucher: field,
    }

    mapping amm_pools: field => PoolInfo; // PoolInfo by hash(token1.id, token2.id)
    mapping amm_deposits: field => u128; // lp deposit amount by hash(id, pool_key)
    mapping amm_extras: field => ExtraAmount; // extra amount by hash(ExtraAmountKey(voucher, token_id))

    inline get_pool_key(token1: u64, token2: u64) -> field {
        let actual_token1: u64 = token1 > token2 ? token2 : token1;
        let actual_token2: u64 = token1 <= token2 ? token2 : token1;
        return BHP256::hash_to_field(PoolKey {token1: token1, token2: token2});
    }

    inline get_extra_amount_key(token_id: u64, voucher: field) -> field {
        return BHP256::hash_to_field(ExtraAmountKey {voucher: voucher, token_id: token_id});
    }

    inline get_deposit_key(holder: address, pool_key: field, deposit_id: field) -> field {
        return BHP256::hash_to_field(DepositKey {holder: holder, pool_key: pool_key, deposit_id: deposit_id});
    }

    inline get_deposit_key_for_tokens(holder: address, token1: u64, token2: u64, deposit_id: field) -> field {
        return get_deposit_key(holder, get_pool_key(token1, token2), deposit_id);
    }

    inline min_u128(a: u128, b: u128) -> u128 {
        return a < b ? a : b;
    }
    transition create_pool(owner: address, token1: Token, initial_amount1: u128, token2: Token, initial_amount2: u128, swap_fee: u128) -> (PoolAdmin, Token, Token) {
        assert(initial_amount1 > 0u128 && initial_amount2 > 0u128);
        assert(swap_fee <= 10000u128); // 10000 based, 1 = 0.01% = 0.0001
        assert(token1.token_id != token2.token_id);
        assert(token1.amount >= initial_amount1 && token2.amount >= initial_amount2);

        let change1: Token = Token {
            owner: owner,
            token_id: token1.token_id,
            amount: token1.amount - initial_amount1
        };

        let change2: Token = Token {
            owner: owner,
            token_id: token2.token_id,
            amount: token2.amount - initial_amount2
        };

        let actual_token1: Token = token1.token_id > token2.token_id ? token2 : token1;
        let actual_token2: Token = token1.token_id < token2.token_id ? token2 : token1;

        let actual_amount1: u128 = token1.token_id > token2.token_id ? initial_amount2 : initial_amount1;
        let actual_amount2: u128 = token1.token_id < token2.token_id ? initial_amount2 : initial_amount1;

        let pool_key: field = get_pool_key(actual_token1.token_id, actual_token2.token_id);
        let pool_admin: PoolAdmin = PoolAdmin {
            owner: owner,
            pool_key: pool_key
        };

        return (pool_admin, change1, change2) then finalize(pool_key, actual_token1.token_id, actual_amount1, actual_token2.token_id, actual_amount2, swap_fee);
    }

    finalize create_pool(pool_key: field, token1_id: u64, token1_amount: u128, token2_id: u64, token2_amount: u128, swap_fee: u128) {
        assert (!Mapping::contains(amm_pools, pool_key)); // the pool already exists

        let pool: PoolInfo = PoolInfo {
            id: pool_key, // hash(token1.id, token2.id)
            token1_id: token1_id,
            token2_id: token2_id,
            reserve1: token1_amount,
            reserve2: token2_amount,
            lp_total_supply: token1_amount * token2_amount,
            swap_fee: swap_fee, // 10000 based, 1 = 0.01% = 0.0001
        };

        Mapping::set(amm_pools, pool_key, pool);
    }

    transition transfer_pool_ownership(poolAdmin: PoolAdmin, to: address) -> (PoolAdmin) {
        assert(poolAdmin.owner == self.caller);
        return PoolAdmin {
            owner: to,
            pool_key: poolAdmin.pool_key
        };
    }

    transition add_amm_liquidity(owner: address, token1: Token, token1_amount: u128, min_token1_amount: u128, token2: Token, token2_amount: u128, min_token2_amount: u128, deposit_id: field) -> (Token, Token, LpTokenReceipt) {
        let token1_change_amount: u128 = token1.amount - token1_amount;
        let token2_change_amount: u128 = token2.amount - token2_amount;
        
        let token1_change_record: Token = Token {
            owner: token1.owner,
            amount: token1_change_amount,
            token_id: token1.token_id
        };
        let token2_change_record: Token = Token {
            owner: token2.owner,
            amount: token2_change_amount,
            token_id: token2.token_id
        };

        let lp_token_receipt: LpTokenReceipt = LpTokenReceipt {
            owner: owner,
            token1_id: token1.token_id,
            token2_id: token2.token_id,
            deposit_id: deposit_id
        };

        let deposit_key: field = get_deposit_key_for_tokens(owner, token1.token_id, token2.token_id, deposit_id);

        return (token1_change_record, token2_change_record, lp_token_receipt) then finalize(deposit_key, token1.token_id, token1_amount, min_token1_amount, token2.token_id, token2_amount, min_token2_amount);
    }

    finalize add_amm_liquidity(deposit_key: field, token1_id: u64, token1_amount: u128, min_token1_amount: u128, token2_id: u64, token2_amount: u128, min_token2_amount: u128) {
        let pool_key: field = get_pool_key(token1_id, token2_id);
        
        let pool: PoolInfo = Mapping::get(amm_pools, pool_key);

        let new_lp1: u128 = (token1_amount * pool.lp_total_supply) / pool.reserve1;
        let new_lp2: u128 = (token2_amount * pool.lp_total_supply) / pool.reserve2;

        let lp: u128 = min_u128(new_lp1, new_lp2);

        // TODO check min_token1_amount & min_token2_amount

        let updated_pool: PoolInfo = PoolInfo {
            id: pool.id,
            token1_id: pool.token1_id,
            token2_id: pool.token2_id,
            swap_fee: pool.swap_fee,
            reserve1: pool.reserve1 + token1_amount,
            reserve2: pool.reserve2 + token2_amount,
            lp_total_supply: pool.lp_total_supply + lp,
        };
        Mapping::set(amm_pools, pool_key, updated_pool);

        assert(!Mapping::contains(amm_deposits, deposit_key));
        Mapping::set(amm_deposits, deposit_key, lp);
    }
    
    transition remove_amm_liquidity(receiver: address, lp_receipt: LpTokenReceipt, token1_amount: u128, token2_amount: u128, extra_voucher: field) -> (Token, Token, ExtraAmountVoucher, ExtraAmountVoucher) {
        let token1: Token = Token {
            owner: receiver,
            amount: token1_amount,
            token_id: lp_receipt.token1_id
        };
        let token2: Token = Token {
            owner: receiver,
            amount: token2_amount,
            token_id: lp_receipt.token2_id
        };

        let extra_amount_voucher1: ExtraAmountVoucher = ExtraAmountVoucher {
            owner: receiver,
            token_id: lp_receipt.token1_id,
            voucher: extra_voucher
        };
        let extra_amount_voucher2: ExtraAmountVoucher = ExtraAmountVoucher {
            owner: receiver,
            token_id: lp_receipt.token2_id,
            voucher: extra_voucher
        };

        let deposit_key: field = get_deposit_key_for_tokens(self.caller, token1.token_id, token2.token_id, lp_receipt.deposit_id);

        return (token1, token2, extra_amount_voucher1, extra_amount_voucher2) then finalize(BHP256::hash_to_field(self.caller), lp_receipt.token1_id, lp_receipt.token2_id, token1_amount, token2_amount, extra_voucher);
    }

    finalize remove_amm_liquidity(deposit_key: field, token1_id: u64, token2_id: u64, token1_amount: u128, token2_amount: u128, extra_voucher: field) {
        let pool_key: field = get_pool_key(token1_id, token2_id);
        let pool: PoolInfo = Mapping::get(amm_pools, pool_key);

        let total: u128 = pool.lp_total_supply;

        let deposit_amount_lp: u128 = Mapping::get(amm_deposits, deposit_key);
        
        let deposit_amount_1: u128 = deposit_amount_lp * pool.reserve1 / total;
        let deposit_amount_2: u128 = deposit_amount_lp * pool.reserve2 / total;
        
        // automatic underflow check ensures a user didn't request more than they have on this deposit
        let change1: u128 = deposit_amount_1 - token1_amount;
        let change2: u128 = deposit_amount_2 - token2_amount;

        let extra1_key: field = get_extra_amount_key(token1_id, extra_voucher); 
        assert (!Mapping::contains(amm_extras, extra1_key)); // check if voucher is already in use
        Mapping::set(amm_extras, extra1_key, ExtraAmount {
            token_id: token1_id,
            token_amount: change1
        });

        let extra2_key: field = get_extra_amount_key(token2_id, extra_voucher);
        assert (!Mapping::contains(amm_extras, extra2_key)); // check if voucher is already in use
        Mapping::set(amm_extras, extra2_key, ExtraAmount {
            token_id: token2_id,
            token_amount: change2
        });

        let updated_pool: PoolInfo = PoolInfo {
            id: pool.id,
            token1_id: pool.token1_id,
            token2_id: pool.token2_id,
            swap_fee: pool.swap_fee,
            reserve1: pool.reserve1 - deposit_amount_1,
            reserve2: pool.reserve2 - deposit_amount_2,
            lp_total_supply: pool.lp_total_supply - deposit_amount_lp
        };
        Mapping::set(amm_pools, pool_key, updated_pool);
        Mapping::remove(amm_deposits, deposit_key);
    }

    transition swap_amm(receiver: address, token_in: Token, amount_in: u128, token_out_id: u64, amount_out: u128, extra_voucher: field) -> (Token, Token, ExtraAmountVoucher) {
        assert(amount_out > 0u128);

        let change_amount: u128 = token_in.amount - amount_in;
        let change: Token = Token {
            owner: token_in.owner,
            amount: change_amount,
            token_id: token_in.token_id
        };

        let token_out: Token = Token {
            owner: receiver,
            amount: amount_out,
            token_id: token_out_id  
        };

        // user can get change using this voucher if amount_out is less than actual amount they could receive according to AMM math
        let extra_amount_voucher: ExtraAmountVoucher = ExtraAmountVoucher {
            owner: receiver,
            token_id: token_out_id,
            voucher: extra_voucher
        };

        return (change, token_out, extra_amount_voucher) then finalize(BHP256::hash_to_field(receiver), token_in.token_id, amount_in, token_out_id, amount_out, extra_voucher);
    }

    finalize swap_amm(receiver: field, token_in_id: u64, amount_in: u128, token_out_id: u64, amount_out: u128, extra_change_voucher: field) {
        let pool_key: field = get_pool_key(token_in_id, token_out_id);
        let pool: PoolInfo = Mapping::get(amm_pools, pool_key);

        let total: u128 = pool.lp_total_supply;

        let reserve_in: u128 = pool.token1_id == token_in_id ? pool.reserve1 : pool.reserve2;
        let reserve_out: u128 = pool.token2_id == token_in_id ? pool.reserve1 : pool.reserve2;

        let fee: u128 = pool.swap_fee;

        let amount_in_with_fee: u128 = amount_in * (10000u128 - fee); 
        let actual_amount_out: u128 = amount_in_with_fee * reserve_out / (reserve_in * 10000u128 + amount_in_with_fee);
        assert(actual_amount_out >= amount_out);

        // Return change
        let extra_change: u128 = actual_amount_out - amount_out;

        let extra_change_key: field = BHP256::hash_to_field(ExtraAmountKey {voucher: extra_change_voucher, token_id: token_out_id});
        
        let extra_amount: ExtraAmount = ExtraAmount {
            token_id: token_out_id,
            token_amount: extra_change,
        };
        Mapping::set(amm_extras, extra_change_key, extra_amount);

        // Update pool
        let reserve_in_new: u128 = reserve_in + amount_in;
        let reserve_out_new: u128 = reserve_out - actual_amount_out;

        let updated_pool: PoolInfo = PoolInfo {
            id: pool.id,
            token1_id: pool.token1_id,
            token2_id: pool.token2_id,
            swap_fee: pool.swap_fee,
            reserve1: pool.token1_id == token_in_id ? reserve_in_new : reserve_out_new,
            reserve2: pool.token2_id == token_in_id ? reserve_in_new : reserve_out_new,
            lp_total_supply: pool.lp_total_supply
        };

        Mapping::set(amm_pools, pool_key, updated_pool);        
    }

    transition redeem_voucher(voucher: ExtraAmountVoucher, amount: u128) -> (Token) {
        let token: Token = Token {
            owner: voucher.owner,
            amount: amount,
            token_id: voucher.token_id
        };
        return token then finalize(voucher.token_id, voucher.voucher, amount);
    }

    finalize redeem_voucher(token_id: u64, voucher_code: field, amount: u128) {
        let key: field = BHP256::hash_to_field(ExtraAmountKey {voucher: voucher_code, token_id: token_id});
        
        let extra: ExtraAmount = Mapping::get(amm_extras, key);
        assert (extra.token_id == token_id && extra.token_amount == amount);
        Mapping::remove(amm_extras, key);
    }

    /// ██████████████████████████████████████████████████████████████████████
    ///                             Private RFQ Swaps 
    /// ██████████████████████████████████████████████████████████████████████
    
    // hash(maker's address) + hash(token_id) ==> balance
    mapping maker_balances: field  => u128;
    mapping executed_quotes: field  => u32;

    struct Deposit {
        maker_address: address,
        token_id: u64,
    }

    transition add_rfq_liquidity(t: Token, maker_address: address, amount: u128) -> Token {
        // let deposit_id: field = Poseidon8::hash_to_field(
        //     Deposit {
        //         maker_address, 
        //         token_id: t.token_id
        //     }
        // );      
        let deposit_id: field = get_deposit_id(maker_address, t.token_id);
        let difference: u128 = t.amount - amount;
        let change: Token = Token {
            owner: t.owner,
            amount: difference,
            token_id: t.token_id,
        };
  
        return change then finalize(
            deposit_id, 
            amount
        );        
    }

    finalize add_rfq_liquidity(deposit_id: field, amount: u128) {
        let balance: u128 = Mapping::get_or_use(maker_balances, deposit_id, 0u128);
        Mapping::set(maker_balances, deposit_id, balance + amount);
    }

    transition remove_rfq_liquidity(token_id: u64, amount: u128) -> Token {
        // let deposit_id: field = Poseidon8::hash_to_field(
        //     Deposit {
        //         maker_address: self.caller, 
        //         token_id
        //     }
        // );      

        let deposit_id: field = get_deposit_id(self.caller, token_id);
        return Token {
            owner: self.caller,
            amount,
            token_id,
        } then finalize(
            deposit_id, 
            amount
        );        
    }
    
    finalize remove_rfq_liquidity(deposit_id: field, amount: u128) {
        let balance: u128 = Mapping::get(maker_balances, deposit_id);
        assert(balance >= amount);
        Mapping::set(maker_balances, deposit_id, balance - amount);
    }

    function get_deposit_id(maker_address: address, token_id: u64) -> field {
        return Poseidon8::hash_to_field(
            Deposit {
                maker_address, 
                token_id
            }
        );      
    }

    transition init_demo_market_maker(dummy: field) -> field {                
        let deposit_1: field = get_deposit_id(aleo1r3qlsxnuux6rkrhk24rktdtzu7kjr3c2fw5fvtp6a9dwghe0xgzs9c2nhu, 1u64);      
        let deposit_2: field = get_deposit_id(aleo1r3qlsxnuux6rkrhk24rktdtzu7kjr3c2fw5fvtp6a9dwghe0xgzs9c2nhu, 2u64);
        let deposit_3: field = get_deposit_id(aleo1r3qlsxnuux6rkrhk24rktdtzu7kjr3c2fw5fvtp6a9dwghe0xgzs9c2nhu, 3u64);
        let deposit_4: field = get_deposit_id(aleo1r3qlsxnuux6rkrhk24rktdtzu7kjr3c2fw5fvtp6a9dwghe0xgzs9c2nhu, 4u64);

        return (dummy + 1field) then finalize(deposit_1, deposit_2, deposit_3, deposit_4);  
    }

    finalize init_demo_market_maker(deposit_1: field, deposit_2: field, deposit_3: field, deposit_4: field) {
        let decimals: u8 = 6u8;
        Mapping::set(maker_balances, deposit_1, 1000000u128 * (10u128 ** decimals));
        Mapping::set(maker_balances, deposit_2, 1000000u128 * (10u128 ** decimals));
        Mapping::set(maker_balances, deposit_3, 1000000u128 * (10u128 ** decimals));
        Mapping::set(maker_balances, deposit_4, 1000000u128 * (10u128 ** decimals));
    }

    struct Quote {
        amount_in: u128,
        amount_out: u128,
        token_in: u64,
        token_out: u64,  
        maker_address: address,      
        nonce: field,
        valid_until: u32,
    }

    transition quote_swap(
        t: Token, 
        q: Quote,
        s: Signature
    ) -> (Token, Token, Token) {
        assert(verify_signature(q,s));

        assert(t.token_id == q.token_in);        
        assert(t.amount >= q.amount_in);

        let delta: u128 = t.amount - q.amount_in;
        let takers_change: Token = Token {
            owner: t.owner,
            amount: delta,
            token_id: t.token_id,
        };

        let takers_out: Token = Token {
            owner: t.owner,
            amount: q.amount_out,
            token_id: q.token_out,
        };

        let makers_in: Token = Token {
            owner: q.maker_address,
            amount: q.amount_in,
            token_id: q.token_in,
        };

        // let withdraw_from: field = Poseidon8::hash_to_field(
        //     Deposit {
        //         maker_address: q.maker_address, 
        //         token_id: q.token_out
        //     }
        // );      
        let withdraw_from: field = get_deposit_id(q.maker_address, q.token_out);      

        return (takers_out, takers_change, makers_in) then finalize(
            withdraw_from, 
            Poseidon8::hash_to_field(q),
            q.amount_out, 
            q.valid_until
        );        
    }

    finalize quote_swap(
        withdraw_from: field, 
        quote_hash: field, 
        amount_out: u128, 
        valid_until: u32
    ) {
        assert(valid_until > block.height);
        assert(!Mapping::contains(executed_quotes, quote_hash));  

        let withdraw_balance: u128 = Mapping::get(maker_balances, withdraw_from);
        assert(withdraw_balance >= amount_out);
        Mapping::set(maker_balances, withdraw_from, withdraw_balance - amount_out);
        
        Mapping::set(executed_quotes, quote_hash, block.height);
    }

    struct Signature {
        challenge: scalar,
        response: scalar,
        pk_sig: group,
        pr_sig: group,
        sk_prf: scalar,
    }


    function verify_signature(q: Quote, s: Signature) -> bool { 
        let g: group = 522678458525321116977504528531602186870683848189190546523208313015552693483group;
        let g_r: group = g * s.response  + s.pk_sig * s.challenge;

        let addr_g: group = q.maker_address as group;

        let g_r_hash: scalar = Poseidon8::hash_to_scalar(g_r);
        let pk_sig_hash: scalar = Poseidon8::hash_to_scalar(s.pk_sig);
        let pr_sig_hash: scalar = Poseidon8::hash_to_scalar(s.pr_sig);
        let addr_hash: scalar = Poseidon8::hash_to_scalar(addr_g);
        let msg_hash: scalar = Poseidon8::hash_to_scalar(q);

        let candidate_challenge: scalar = g_r_hash + pk_sig_hash + pr_sig_hash + addr_hash + msg_hash;

        let g_addr: group = s.pk_sig + s.pr_sig + g * s.sk_prf;
        let addr_flag: bool = g_addr == addr_g;
        let challenge_flag: bool = s.challenge == candidate_challenge;
        return addr_flag && challenge_flag;
    }

    /// ██████████████████████████████████████████████████████████████████████
    ///                             DEMO 
    /// ██████████████████████████████████████████████████████████████████████

    transition init_demo_tokens(dummy: field) -> field {
        return (dummy + 1field) then finalize(dummy);  
    }

    finalize init_demo_tokens(dummy: field) {
        let decimals: u8 = 6u8;

        Mapping::set(registered_tokens, 1u64, TokenInfo {
             token_id: 1u64,
             max_supply: 1000000000u128 * (10u128 ** decimals),
             decimals,
        });    
        Mapping::set(registered_tokens, 2u64, TokenInfo {
             token_id: 2u64,
             max_supply: 1000000000u128 * (10u128 ** decimals),
             decimals,
        });    
        Mapping::set(registered_tokens, 3u64, TokenInfo {
             token_id: 3u64,
             max_supply: 1000000000u128 * (10u128 ** decimals),
             decimals,
        });    
        Mapping::set(registered_tokens, 4u64, TokenInfo {
             token_id: 4u64,
             max_supply: 1000000000u128 * (10u128 ** decimals),
             decimals,
        });    
    }


    transition init_demo_pools(dummy: field) {
        return then finalize();
    }

    finalize init_demo_pools() {
        let reserve1: u128 = 100000000000000u128;
        let reserve2: u128 = 100000000000000u128;
        let reserve3: u128 = 50000000000u128;
        let reserve4: u128 = 500000000000u128;

        let pool12_key: field = get_pool_key(1u64, 2u64);
        let pool12: PoolInfo = PoolInfo {
            id: pool12_key, // hash(token1.id, token2.id)
            token1_id: 1u64,
            token2_id: 2u64,
            reserve1: reserve1,
            reserve2: reserve2,
            lp_total_supply: reserve1 * reserve2,
            swap_fee: 10u128, // 10000 based, 1 = 0.01% = 0.0001
        };
        assert(!Mapping::contains(amm_pools, pool12_key));
        Mapping::set(amm_pools, pool12_key, pool12); 

        let pool13_key: field = get_pool_key(1u64, 3u64);
        let pool13: PoolInfo = PoolInfo {
            id: pool13_key,
            token1_id: 1u64,
            token2_id: 3u64,
            reserve1: reserve1,
            reserve2: reserve3,
            lp_total_supply: reserve1 * reserve3,
            swap_fee: 10u128, // 10000 based, 1 = 0.01% = 0.0001
        };
        Mapping::set(amm_pools, pool13_key, pool13); 

        let pool14_key: field = get_pool_key(1u64, 4u64);
        let pool14: PoolInfo = PoolInfo {
            id: pool14_key,
            token1_id: 1u64,
            token2_id: 4u64,
            reserve1: reserve1,
            reserve2: reserve4,
            lp_total_supply: reserve1 * reserve4,
            swap_fee: 10u128,
        };
        Mapping::set(amm_pools, pool14_key, pool14); 

        let pool23_key: field = get_pool_key(2u64, 3u64);
        let pool23: PoolInfo = PoolInfo {
            id: pool23_key, // hash(token1.id, token2.id)
            token1_id: 2u64,
            token2_id: 3u64,
            reserve1: reserve2,
            reserve2: reserve3,
            lp_total_supply: reserve2 * reserve3,
            swap_fee: 10u128,
        };
        Mapping::set(amm_pools, pool23_key, pool23); 

        let pool24_key: field = get_pool_key(2u64, 4u64);
        let pool24: PoolInfo = PoolInfo {
            id: pool24_key,
            token1_id: 2u64,
            token2_id: 4u64,
            reserve1: reserve2,
            reserve2: reserve4,
            lp_total_supply: reserve2 * reserve4,
            swap_fee: 10u128,
        };
        Mapping::set(amm_pools, pool24_key, pool24); 

        let pool34_key: field = get_pool_key(3u64, 4u64);
        let pool34: PoolInfo = PoolInfo {
            id: pool34_key,
            token1_id: 3u64,
            token2_id: 4u64,
            reserve1: reserve3,
            reserve2: reserve4,
            lp_total_supply: reserve3 * reserve4,
            swap_fee: 10u128,
        };
        Mapping::set(amm_pools, pool34_key, pool34); 
    }

}