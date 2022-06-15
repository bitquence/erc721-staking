
# ERC721 Staking 🪙

ERC721 staking contract built with a focus on performance and safety, taking in ERC721 tokens and emitting yield in the form of an ERC20 token over time.

`BASE_TOKEN` holders can lock their tokens in this contract, to earn yield in the form of `EMISSION_TOKEN`.

The distinction between this contract and other contracts of the like is in its storage layout, staked tokens are not indexed in storage by their token ID, but by the address of the user, which makes it cheap to stake multiple tokens at once, **with the only caveat to this being that the user cannot withdraw a single token and must withdraw their entire stake at once**.  Additionally, any function that changes the user's stake must also automatically claim the user's accrued yield, so that the `lastClaimedAt` timestamp of the user's stake is updated.

An assumption is made that `BASE_TOKEN` is an ERC721 token **with no tokens having a token ID higher than 2 ^ 16 (65536)**, and `EMISSION_TOKEN` is an ERC20 token which the staking contract must hold a sufficient amount of in order to emit yield without interruption.

The default values of this contract make it emit 10 tokens every 6000 blocks (approximately one day on Ethereum's main network), but it is possible to change these values during or after deployment by changing the values in the code or via the `setEmissionFrequency(uint128 _new)` and `setEmissionAmount(uint128 _new)` functions.

##### ⚠️ Warning: none of the code in this repository has been audited externally, please exert due diligence if using this code in a production environment.
##### Built on top of OpenZeppelin's Ownable and ERC721 library.

## Building/Testing

### Requirements
- [Foundry](https://getfoundry.sh/) ([more in-depth guide here](https://book.getfoundry.sh/))
- [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)


```sh
git clone https://github.com/bitquence/erc721-staking.git
cd erc721-staking
# the vm's block number must be set to any non-zero value when running tests
forge build && forge test --gas-report --block-number 1000000
```

## Deployment/Etherscan Verification

```sh
forge create --rpc-url <your_rpc_url> \
    --constructor-args <your_emission_token> <your_base_token> \
    --private-key <your_private_key> src/Staking.sol:Staking \
    --verify
```

## To Do
- [ ] Add support for unstaking singular tokens
- [ ] Deployment scripts/Makefile