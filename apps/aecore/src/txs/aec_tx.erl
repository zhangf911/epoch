-module(aec_tx).

-export([apply_signed/3,
         hash/1]).

-include("common.hrl").
-include("trees.hrl").
-include("txs.hrl").

%% aec_tx behavior callbacks

-callback new(Args :: map(), Trees :: trees()) ->
    {ok, Tx :: term()}.

-callback run(Tx :: term(), Trees :: trees(), Height :: non_neg_integer()) ->
    {ok, NewTrees :: trees()} | {error, Reason :: term()}.

%% API

-spec apply_signed(list(signed_tx()), trees(), non_neg_integer()) -> {ok, trees()} | {error, term()}.
apply_signed([], Trees, _Height) ->
    {ok, Trees};
apply_signed([SignedTx | Rest], Trees0, Height) ->
    case aec_tx_sign:verify(SignedTx) of
        ok ->
            FeedTx = aec_tx_sign:data(SignedTx),
            case aec_tx_fee:check(FeedTx) of
                ok ->
                    Tx = aec_tx_fee:tx(FeedTx),
                    case apply_single(Tx, Trees0, Height) of
                        {ok, Trees} ->
                            apply_signed(Rest, Trees, Height);
                        {error, _Reason} = Error ->
                            Error
                    end
                %{error, _Reason} = Error->
                %    Error
            end;
        {error, _Reason} = Error ->
            Error
    end.

-spec hash(signed_tx()) -> binary().
hash(_SignedTx) ->
    <<0:8>>. %TODO implement, we need tx serialization for that, then we can do it like: crypto:hash(sha256,SerializedSignedTx).

%% Internal functions

-spec apply_single(tx(), trees(), non_neg_integer()) -> {ok, trees()} | {error, term()}.
apply_single(#coinbase_tx{} = Tx, Trees, Height) ->
    aec_coinbase_tx:run(Tx, Trees, Height);
apply_single(_Other, _Trees_, _Height) ->
    {error, not_implemented}.
