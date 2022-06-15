// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ERC721 staking contract taking in ERC721 tokens and emitting yield in
 * the form of an ERC20 token over time.
 * @author Jonathan <@bitquence>
 * @dev Holders of `BASE_TOKEN` are able to lock their tokens in this contract,
 * to earn yield in the form of `EMISSION_TOKEN`. The distinction between this
 * contract and other contracts of the like is found in its storage layout,
 * staked tokens are not indexed in storage by their token ID, but by the
 * address of the staker, which makes it cheap to stake multiple tokens at once,
 * **with the only caveat to this being that the staker cannot withdraw a single
 * token and must withdraw their entire stake at once**.
 *
 * Additionally, any function that changes the user's stake must also
 * automatically claim the user's accrued yield, so that the `lastClaimedAt`
 * timestamp is updated.
 *
 * Requirements:
 *
 * - `BASE_TOKEN` must be an ERC721 token with no tokens having an ID higher
 * than 2 ^ 16 (65536).
 * - `EMISSION_TOKEN` must be an ERC20 token which this contract holds a
 * sufficient amount of in order to properly emit yield.
 */
contract Staking is Ownable, IERC721Receiver {
    event TokensStaked(address indexed by, uint16[] tokenIds);
    event StakeWithdrawn(address indexed by, uint16[] tokenIds);
    event RewardClaimed(address indexed by, uint256 amount);

    /*
     * @dev Structure representing all of a user's staked tokens, and the block
     * number at which they last claimed their rewards at.
     *
     * This structure is meant to be accessed by the user's address, which is
     * why it does not store the address of the user the stake belongs to.
     * 
     * The `lastClaimedAt` field is used to determine whether a user has already
     * staked tokens or not, by comparing it to the default value of 0.
     * @param lastClaimedAt The block at which the user last claimed their
     * tokens at, should be zeroed out if the user has not staked any tokens
     * yet.
     * @param tokenIds All of the user's staked token IDs, we assume here that
     * the tokens do not have an ID higher than 2 ^ 16 (65536).
     */
    struct Stake {
        uint48 lastClaimedAt;
        uint16[] tokenIds;
    }

    IERC20 public immutable EMISSION_TOKEN;
    IERC721 public immutable BASE_TOKEN;

    /**
     * @dev The number of blocks between token emissions, defaults at 6000
     * blocks (approximately one day on Ethereum's main network).
     */
    uint128 public emissionFrequency = 6000;

    /**
     * @dev The amount of `EMISSION_TOKEN` to emit per emission, defaults at 10
     * tokens.
     */
    uint128 public emissionAmount = 10 * 10e18;

    mapping(address => Stake) internal stakes;

    constructor(IERC20 emissionToken, IERC721 baseToken) {
        EMISSION_TOKEN = emissionToken;
        BASE_TOKEN = baseToken;
    }

    /**
     * @dev Sets the number of blocks between token emissions.
     */
    function setEmissionFrequency(uint128 _new) external onlyOwner {
        emissionFrequency = _new;
    }

    /**
     * @dev Sets the amount of tokens to emit per emission, must take into
     * account the decimals of the emission token.
     */
    function setEmissionAmount(uint128 _new) external onlyOwner {
        emissionAmount = _new;
    }

    /*
     * @notice Attempts to transfer all tokens IDs in the given array to itself
     * and then registers a stake for the caller, will also award the caller's
     * rewards if the user has already staked tokens and has any available.
     */
    function stakeTokens(uint16[] calldata ids) external {
        require(ids.length > 0, "Staking: must be staking more than 0 tokens");

        Stake memory stake = stakes[msg.sender];

        // User has already staked tokens.
        if (stake.lastClaimedAt != 0) {
            uint256 reward = _rewardOf(stake);
            stakes[msg.sender].lastClaimedAt = uint48(block.number);

            for (uint256 i; i < ids.length; i++) {
                BASE_TOKEN.transferFrom(msg.sender, address(this), ids[i]);
                stakes[msg.sender].tokenIds.push(ids[i]);
            }

            if (reward > 0) {
                EMISSION_TOKEN.transfer(msg.sender, reward);

                emit RewardClaimed(msg.sender, reward);
            }
        } else {
            uint48 currentBlock = uint48(block.number);

            for (uint256 i; i < ids.length; i++) {
                BASE_TOKEN.transferFrom(msg.sender, address(this), ids[i]);
            }

            stakes[msg.sender] = Stake({
                lastClaimedAt: currentBlock,
                tokenIds: ids
            });
        }

        emit TokensStaked(msg.sender, ids);
    }

    /*
     * @notice Withdraws every one of the user's staked tokens, will also award
     * the caller's rewards if the user has already staked tokens and has any
     * available.
     */
    function withdrawStake() external {
        Stake memory stake = stakes[msg.sender];
        uint256 reward = _rewardOf(stake);

        require(stake.lastClaimedAt != 0, "Staking: you have no tokens staked");

        for (uint256 i; i < stake.tokenIds.length; i++) {
            BASE_TOKEN.transferFrom(
                address(this),
                msg.sender,
                stake.tokenIds[i]
            );
        }

        if (reward > 0) {
            EMISSION_TOKEN.transfer(msg.sender, reward);

            emit RewardClaimed(msg.sender, reward);
        }

        delete stakes[msg.sender];

        emit StakeWithdrawn(msg.sender, stake.tokenIds);
    }

    /*
     * @notice Awards a user their pending rewards and updates the timestamp
     * their rewards have last been claimed at.
     */
    function claimReward() external {
        uint256 reward = _rewardOf(stakes[msg.sender]);
        stakes[msg.sender].lastClaimedAt = uint48(block.number);

        if (reward > 0) {
            EMISSION_TOKEN.transfer(msg.sender, reward);

            emit RewardClaimed(msg.sender, reward);
        }
    }

    function rewardOf(address who) public view returns (uint256) {
        return _rewardOf(stakes[who]);
    }

    function _rewardOf(Stake memory stake)
        internal
        view
        returns (uint256 reward)
    {
        uint48 currentBlock = uint48(block.number);

        if (stake.lastClaimedAt >= currentBlock || stake.tokenIds.length == 0)
            return 0;

        uint256 rate = emissionAmount / emissionFrequency;

        return
            rate * (currentBlock - stake.lastClaimedAt) * stake.tokenIds.length;
    }

    function stakeOf(address who) public view returns (Stake memory) {
        return stakes[who];
    }

    /*
     * @notice Withdraws `amount` of the `EMISSION_TOKEN` tokens to the caller.
     *
     * Requirements:
     *
     * - the caller must be the owner of this contract
     */
    function withdrawTokens(uint256 amount) external onlyOwner {
        EMISSION_TOKEN.transfer(msg.sender, amount);
    }

    /**
     * @dev Forbid anyone from sending ERC721 tokens to this contract, and
     * instead redirect them to a page that will assist them in staking their
     * tokens.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        revert("Staking: please refer to staking.example.com");
    }
}
