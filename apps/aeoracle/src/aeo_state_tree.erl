%%%-------------------------------------------------------------------
%%% @copyright (C) 2017, Aeternity Anstalt
%%% @doc
%%% ADT for keeping the state of oracles
%%% @end
%%%-------------------------------------------------------------------

-module(aeo_state_tree).

%% API
-export([ get_interaction/2
        , get_oracle/2
        , empty/0
        , enter_interaction/2
        , enter_oracle/2
        , lookup_interaction/2
        , lookup_oracle/2
        , prune/2
        , root_hash/1
        ]).

%%%===================================================================
%%% Types
%%%===================================================================

-type mtree() :: aeu_mtrees:tree(binary(), binary()).
-type interaction() :: aeo_interaction:interaction().
-type oracle() :: aeo_oracles:oracle().
%% -type cache() :: {integer(), [binary()], [binary()]}.
-type cache() :: gb_sets:set({integer(), binary()}).
-type block_height() :: non_neg_integer().

-record(oracle_tree, { mtree = gb_merkle_trees:empty() :: mtree()
                     , cache = cache_new() :: cache()
                     }).

-opaque tree() :: #oracle_tree{}.

-export_type([ tree/0
             ]).

%%%===================================================================
%%% API
%%%===================================================================

-spec empty() -> tree().
empty() ->
    MTree = aeu_mtrees:empty(),
    #oracle_tree{ mtree = MTree
                , cache = cache_new()
                }.

-spec prune(block_height(), tree()) -> tree().
prune(Height, #oracle_tree{} = Tree) ->
    %% TODO: We need to know what we pruned as well
    int_prune(Height, Tree).

-spec enter_interaction(interaction(), tree()) -> tree().
enter_interaction(I, Tree) ->
    Id = aeo_interaction:id(I),
    Serialized = aeo_interaction:serialize(I),
    Expires = aeo_interaction:expires(I),
    enter_common(Id, Expires, Serialized, Tree).

-spec get_interaction(binary(), tree()) -> interaction().
get_interaction(Id, Tree) ->
    aeo_interaction:deserialize(aeu_mtrees:get(Id, Tree#oracle_tree.mtree)).

-spec lookup_interaction(binary(), tree()) -> {'value', interaction()} | none.
lookup_interaction(Id, Tree) ->
    case aeu_mtrees:lookup(Id, Tree#oracle_tree.mtree) of
      {value, Val} -> {value, aeo_interaction:deserialize(Val)};
      none -> none
    end.

-spec enter_oracle(oracle(), tree()) -> tree().
enter_oracle(O, Tree) ->
    Id = aeo_oracles:id(O),
    Serialized = aeo_oracles:serialize(O),
    Expires = aeo_oracles:expires(O),
    enter_common(Id, Expires, Serialized, Tree).

-spec get_oracle(binary(), tree()) -> oracle().
get_oracle(Id, Tree) ->
    aeo_oracles:deserialize(aeu_mtrees:get(Id, Tree#oracle_tree.mtree)).

-spec lookup_oracle(binary(), tree()) -> {'value', oracle()} | 'none'.
lookup_oracle(Id, Tree) ->
    case aeu_mtrees:lookup(Id, Tree#oracle_tree.mtree) of
        {value, Val}  -> {value, aeo_oracles:deserialize(Val)};
        none -> none
    end.

-spec root_hash(tree()) -> {ok, aeu_mtrees:root_hash()} | {error, empty}.
root_hash(#oracle_tree{mtree = MTree}) ->
    aeu_mtrees:root_hash(MTree).


%%%===================================================================
%%% Internal functions
%%%===================================================================

enter_common(Id, Expires, Serialized, Tree) ->
    MTree1 = aeu_mtrees:enter(Id, Serialized, Tree#oracle_tree.mtree),
    Cache = cache_push(Id, Expires, Tree#oracle_tree.cache),
    Tree#oracle_tree{ mtree = MTree1
                    , cache = Cache
                    }.

int_prune(Height, #oracle_tree{cache = Cache, mtree = MTree} = Tree) ->
    case cache_safe_peek(Cache) of
        {H, _} when H > Height -> Tree;
        Other ->
            {Cache1, Mtree1} = int_prune(Other, Height, Cache, MTree),
            Tree#oracle_tree{ cache = Cache1
                            , mtree = Mtree1}
    end.

int_prune(none,_Height, Cache, MTree) ->
    {Cache, MTree};
int_prune({Height, Id}, Height, Cache, MTree) ->
    {Id, Cache1} = cache_pop(Cache),
    MTree1 = aeu_mtrees:delete(Id, MTree),
    int_prune(cache_safe_peek(Cache1), Height, Cache1, MTree1);
int_prune({Height1,_Id}, Height2, Cache, MTree) when Height2 > Height1 ->
    {Cache, MTree}.


%%%===================================================================
%%% TTL Cache
%%%===================================================================

cache_new() ->
    gb_sets:empty().

cache_push(Id, Expires, C) ->
    gb_sets:add({Expires, Id}, C).

cache_safe_peek(C) ->
    case gb_sets:is_empty(C) of
        true  -> none;
        false -> gb_sets:smallest(C)
    end.

cache_pop(C) ->
    gb_sets:take_smallest(C).

