program rfq_v000003.aleo {

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
             token_id: 1u64,
             max_supply: 1000000000u128 * (10u128 ** decimals),
             decimals,
        });    
        Mapping::set(registered_tokens, 3u64, TokenInfo {
             token_id: 1u64,
             max_supply: 1000000000u128 * (10u128 ** decimals),
             decimals,
        });    
        Mapping::set(registered_tokens, 4u64, TokenInfo {
             token_id: 1u64,
             max_supply: 1000000000u128 * (10u128 ** decimals),
             decimals,
        });    
    }

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
    ///                             Private RFQ Swaps 
    /// ██████████████████████████████████████████████████████████████████████
    
    // hash(maker's address) + hash(token_id) ==> balance
    mapping maker_balances: field  => u128;
    mapping executed_quotes: field  => u32;

    struct Deposit {
        maker_address: address,
        token_id: u64,
    }

    transition add_liquidity(t: Token, maker_address: address, amount: u128) -> Token {
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

    finalize add_liquidity(deposit_id: field, amount: u128) {
        let balance: u128 = Mapping::get_or_use(maker_balances, deposit_id, 0u128);
        Mapping::set(maker_balances, deposit_id, balance + amount);
    }

    transition remove_liquidity(token_id: u64, amount: u128) -> Token {
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
    
    finalize remove_liquidity(deposit_id: field, amount: u128) {
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

}
