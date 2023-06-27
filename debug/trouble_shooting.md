#  Error Codes

## file location: `./erhai-core/types/errors/errors.go`

## `ErrUnauthorized = Register(RootCodespace, 4, "unauthorized")`

file list:

```
./erhai-core/types/tx/types.go
./erhai-core/types/errors/errors.go
./erhai-core/module/auth/legacy/legacytx/stdtx.go
./erhai-core/module/auth/vesting/msg_server.go
./erhai-core/module/auth/ante/sigverify.go
./erhai-core/module/bank/keeper/keeper.go
./erhai-core/module/bank/keeper/msg_server.go
./erhai-core/baseapp/abci.go
./erhai-core/client/query.go
./mod-wasm/keeper/handler_plugin.go
./mod-wasm/keeper/keeper.go
```

This error happened when the evm contract was invoked. As a result, it is not related to wasm and bank modules.

### file: `./erhai-core/types/tx/types.go`

```
        if len(sigs) != len(t.GetSigners()) {
                return sdkerrors.Wrapf(
                        sdkerrors.ErrUnauthorized,
                        "wrong number of signers; expected %d, got %d", len(t.GetSigners()), len(sigs),
                )
        }
```

### file: `./erhai-core/module/auth/legacy/legacytx/stdtx.go`

```
        if len(stdSigs) != len(tx.GetSigners()) {
                return sdkerrors.Wrapf(
                        sdkerrors.ErrUnauthorized,
                        "wrong number of signers; expected %d, got %d", len(tx.GetSigners()), len(stdSigs),
                )
        }
```

### file: `./erhai-core/module/auth/ante/sigverify.go`

```
        if len(sigs) != len(signerAddrs) {
                return ctx, sdkerrors.Wrapf(sdkerrors.ErrUnauthorized, "invalid number of signer;  expected: %d, got %d", len(signerAddrs), l
en(sigs))
        }
```

```
        // check that signer length and signature length are the same
        if len(sigs) != len(signerAddrs) {
                return ctx, sdkerrors.Wrapf(sdkerrors.ErrUnauthorized, "invalid number of signer;  expected: %d, got %d", len(signerAddrs), l
en(sigs))
        }
```

### file: `./erhai-core/baseapp/abci.go`

```
        case codes.Unauthenticated:
                return sdkerrors.Wrap(sdkerrors.ErrUnauthorized, err.Error())
```

### file: `./erhai-core/client/query.go`

```
func sdkErrorToGRPCError(resp abci.ResponseQuery) error {
        switch resp.Code {
        case sdkerrors.ErrInvalidRequest.ABCICode():
                return status.Error(codes.InvalidArgument, resp.Log)
        case sdkerrors.ErrUnauthorized.ABCICode():
                return status.Error(codes.Unauthenticated, resp.Log)
        case sdkerrors.ErrKeyNotFound.ABCICode():
                return status.Error(codes.NotFound, resp.Log)
        default:
                return status.Error(codes.Unknown, resp.Log)
        }
}
```

## Error code: `Unauthenticated`

file list:

```
./mod-tbft/third_party/gmsm/sm2/pkcs7.go
./erhai-core/baseapp/abci.go
./erhai-core/client/query.go
```

### file: `./erhai-core/baseapp/abci.go`

```
type signerInfo struct {
        Version                   int `asn1:"default:1"`
        IssuerAndSerialNumber     issuerAndSerial
        DigestAlgorithm           pkix.AlgorithmIdentifier
        AuthenticatedAttributes   []attribute `asn1:"optional,tag:0"`
        DigestEncryptionAlgorithm pkix.AlgorithmIdentifier
        EncryptedDigest           []byte
        UnauthenticatedAttributes []attribute `asn1:"optional,tag:1"`
}
```

### Wrap up 

It is signature problem when error code 4 is thrown. The client should check how transaction is constructed.


# Block time 

## file location: `./erhai-core/core/state/state.go`

```
func (state State) MakeBlock(
        height int64,
        txs []types.Tx,
        commit *types.Commit,
        evidence []types.Evidence,
        proposerAddress []byte,
) (*types.Block, *types.PartSet) {

        // Build base block with block data.
        block := types.MakeBlock(height, txs, commit, evidence)

        // Set time.
        var timestamp time.Time
        if height == state.InitialHeight {
                timestamp = state.LastBlockTime // genesis time
        } else {
                if state.ConsensusParams.Type == tmproto.ConsensusParams_TENDERMINT {
                        timestamp = MedianTime(commit, state.LastValidators)
                } else {
                        timestamp = time.Now()
                }

        }

        // Fill rest of header with state data.
        block.Header.Populate(
                state.Version.Consensus, state.ChainID,
                timestamp, state.LastBlockID,
```

```
func MedianTime(commit *types.Commit, validators *types.ValidatorSet) time.Time {
        weightedTimes := make([]*tmtime.WeightedTime, len(commit.Signatures))
        totalVotingPower := int64(0)

        for i, commitSig := range commit.Signatures {
                if commitSig.Absent() {
                        continue
                }
                _, validator := validators.GetByAddress(commitSig.ValidatorAddress)
                // If there's no condition, TestValidateBlockCommit panics; not needed normally.
                if validator != nil {
                        totalVotingPower += validator.VotingPower
                        weightedTimes[i] = tmtime.NewWeightedTime(commitSig.Timestamp, validator.VotingPower)
                }
        }

        return tmtime.WeightedMedian(weightedTimes, totalVotingPower)
}
```

## file location: `./erhai-core/core/state/execution.go`

```
func (blockExec *BlockExecutor) CreateProposalBlock(
        height int64,
        state State, commit *types.Commit,
        proposerAddr []byte,
) (*types.Block, *types.PartSet) {

        maxBytes := state.ConsensusParams.Block.MaxBytes
        maxGas := state.ConsensusParams.Block.MaxGas

        var evidence []types.Evidence
        var evSize int64
        if state.ConsensusParams.Type == tmproto.ConsensusParams_TENDERMINT {
                evidence, evSize = blockExec.evpool.PendingEvidence(state.ConsensusParams.Evidence.MaxBytes)
        } else {
                evidence = []types.Evidence{}
                evSize = 0
        }

        // Fetch a limited amount of valid txs
        maxDataBytes := types.MaxDataBytes(maxBytes, evSize, state.Validators.Size())

        txs := blockExec.mempool.ReapMaxBytesMaxGas(maxDataBytes, maxGas)

        return state.MakeBlock(height, txs, commit, evidence, proposerAddr)
}
```

## file location: `./erhai-core/core/consensus/state.go`

```
func (cs *State) createProposalBlock() (block *types.Block, blockParts *types.PartSet) {
        if cs.privValidator == nil {
                panic("entered createProposalBlock with privValidator being nil")
        }

        var commit *types.Commit
        switch {
        case cs.Height == cs.state.InitialHeight:
                // We're creating a proposal for the first block.
                // The commit is empty, but not nil.
                commit = types.NewCommit(0, 0, types.BlockID{}, nil)

        case cs.LastCommit.HasTwoThirdsMajority():
                // Make the commit from LastCommit
                commit = cs.LastCommit.MakeCommit()

        default: // This shouldn't happen.
                cs.Logger.Error("propose step; cannot propose anything without commit for the previous block")
                return
        }

        if cs.privValidatorPubKey == nil {
                // If this node is a validator & proposer in the current round, it will
                // miss the opportunity to create a block.
                cs.Logger.Error("propose step; empty priv validator public key", "err", ErrPubKeyIsNotSet)
                return
        }

        proposerAddr := cs.privValidatorPubKey.Address()

        return cs.blockExec.CreateProposalBlock(cs.Height, cs.state, commit, proposerAddr)
```

```
func (cs *State) defaultDecideProposal(height int64, round int32) {
        var block *types.Block
        var blockParts *types.PartSet

        // Decide on block
        if cs.ValidBlock != nil {
                // If there is valid block, choose that.
                block, blockParts = cs.ValidBlock, cs.ValidBlockParts
        } else {
                // Create a new proposal block from state/txs from the mempool.
                block, blockParts = cs.createProposalBlock()
                if block == nil {
                        return
                }
        }
```

```
func (cs *State) enterPropose(height int64, round int32) {
```

```
case cstypes.RoundStepNewRound:
                cs.enterPropose(ti.Height, 0)                    
```

```
 // Wait for txs to be available in the mempool
        // before we enterPropose in round 0. If the last block changed the app hash,
        // we may need an empty "proof" block, and enterPropose immediately.
        waitForTxs := cs.config.WaitForTxs() && round == 0 && !cs.needProofBlock(height)
        if waitForTxs {
                if cs.config.CreateEmptyBlocksInterval > 0 {
                        cs.scheduleTimeout(cs.config.CreateEmptyBlocksInterval, height, round,
                                cstypes.RoundStepNewRound)
                }
        } else {
                cs.enterPropose(height, round)
        }
```

## file location: `./erhai-core/core/config/config.go`
```
func (cfg *ConsensusConfig) WaitForTxs() bool {
        return !cfg.CreateEmptyBlocks || cfg.CreateEmptyBlocksInterval > 0
}
```

When the empty block is disabled, the `WaitForTxs` function always returns true.

There is additional check for proof block. This is the reason under the hood.

## Tx timestamp

```
func NewResponseResultTx(res *ctypes.ResultTx, anyTx *codectypes.Any, timestamp string) *TxResponse {
	if res == nil {
		return nil
	}

	parsedLogs, _ := ParseABCILogs(res.TxResult.Log)

	return &TxResponse{
		TxHash:    res.Hash.String(),
		Height:    res.Height,
		Codespace: res.TxResult.Codespace,
		Code:      res.TxResult.Code,
		Data:      strings.ToUpper(hex.EncodeToString(res.TxResult.Data)),
		RawLog:    res.TxResult.Log,
		Logs:      parsedLogs,
		Info:      res.TxResult.Info,
		GasWanted: res.TxResult.GasWanted,
		GasUsed:   res.TxResult.GasUsed,
		Tx:        anyTx,
		Timestamp: timestamp,
```

```
func mkTxResult(txConfig client.TxConfig, resTx *ctypes.ResultTx, resBlock *ctypes.ResultBlock) (*sdk.TxResponse, error) {
	txb, err := txConfig.TxDecoder()(resTx.Tx)
	if err != nil {
		return nil, err
	}
	p, ok := txb.(intoAny)
	if !ok {
		return nil, fmt.Errorf("expecting a type implementing intoAny, got: %T", txb)
	}
	any := p.AsAny()
	return sdk.NewResponseResultTx(resTx, any, resBlock.Block.Time.Format(time.RFC3339)), nil
}
```
