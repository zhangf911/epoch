%%%-------------------------------------------------------------------
%%% @copyright (C) 2017, Aeternity Anstalt
%%% @doc Genesis block definition.
%%%
%%% The genesis block does not follow the validation rules of the
%%% other blocks because:
%%% * It is unmined;
%%%   * It implies genesis block cannot be validated PoW wise.
%%% * Its time is epoch i.e. much in the past;
%%%   * It implies the time difference between genesis block and first
%%%     block is very large - that may be considered abnormal for
%%%     successive blocks (e.g. between blocks 1 and 2 - with block 0
%%%     being genesis).
%%% * It contains no transactions - not even coinbase;
%%%   * This means that validation function attempting to check that
%%%     there is at least a coinbase transaction in a block needs to
%%%     have a special case for genesis.
%%% * The hash values in it may have special values i.e. all zeros.
%%%   * This means that validation function attempting to consider the
%%%     hashes in a block needs to have a special case for genesis.
%%% @end
%%%-------------------------------------------------------------------
-module(aec_block_genesis).

%% API
-export([ genesis_header/0,
          height/0,
          genesis_block_with_state/0,
          genesis_block_with_state/1,
          populated_trees/0 ]).

-include("common.hrl").
-include("blocks.hrl").

%% Since preset accounts are being loaded from a file - please use with caution
genesis_header() ->
    {ok, B, _S} = genesis_block_with_state(),
    aec_blocks:to_header(B).

%% Returns the genesis block and the state trees.
%%
%% The current implementation of state trees causes a new Erlang term,
%% representing the initial state trees, to be allocated in the
%% heap memory of the calling process.
%%
%% Since preset accounts are being loaded from a file - please use with caution
genesis_block_with_state() ->
  genesis_block_with_state(aec_genesis_block_settings:preset_accounts()).

genesis_block_with_state(PresetAccounts) ->
    Trees = populated_trees(PresetAccounts),
    Block =
        #block{
           version = ?GENESIS_VERSION,
           height = ?GENESIS_HEIGHT,
           prev_hash = <<0:?BLOCK_HEADER_HASH_BYTES/unit:8>>,
           txs_hash = <<0:?TXS_HASH_BYTES/unit:8>>,
           root_hash = aec_trees:hash(Trees),
           target = ?HIGHEST_TARGET_SCI,
           pow_evidence = no_value,
           nonce = 0,
           time = 0 %% Epoch.
          },
    {ok, Block, Trees}.

populated_trees() ->
    populated_trees(aec_genesis_block_settings:preset_accounts()).

populated_trees(PresetAccounts) ->
    EmptyStateTrees = aec_trees:new(),
    PopulatedAccountsTree =
        lists:foldl(fun({PubKey, Amount}, T) ->
                            Account = aec_accounts:new(PubKey, Amount, ?GENESIS_HEIGHT),
                            aec_accounts_trees:enter(Account, T)
                    end, aec_trees:accounts(EmptyStateTrees), PresetAccounts),
    aec_trees:set_accounts(EmptyStateTrees, PopulatedAccountsTree).

height() ->
    ?GENESIS_HEIGHT.
