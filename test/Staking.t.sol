// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/Staking.sol";
import "./mocks/MockERC20.sol";
import "./mocks/MockERC721.sol";

contract StakingTest is Test {
    MockERC20 emission;
    MockERC721 base;
    Staking staking;

    function setUp() public {
        emission = new MockERC20();
        base = new MockERC721();
        staking = new Staking(emission, base);

        emission.mint(address(staking), type(uint256).max);
    }

    // -------------------------------- STAKING --------------------------------

    /// @dev Mints and attemps to stake a single token
    function testStakeToken() public {
        uint16[] memory tokenIds = new uint16[](1);
        tokenIds[0] = 0;

        base.mint(address(this), 1);

        base.setApprovalForAll(address(staking), true);

        staking.stakeTokens(tokenIds);

        assertEq(base.balanceOf(address(this)), 0);
        assertEq(base.balanceOf(address(staking)), 1);
        assertEq(staking.stakeOf(address(this)).lastClaimedAt, block.number);
        assertEq(staking.stakeOf(address(this)).tokenIds[0], tokenIds[0]);
    }

    /// @dev Mints and attemps to stake 3 tokens
    function testStakeTokens() public {
        uint16[] memory tokenIds = new uint16[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;

        base.mint(address(this), 3);

        base.setApprovalForAll(address(staking), true);

        staking.stakeTokens(tokenIds);

        assertEq(base.balanceOf(address(this)), 0);
        assertEq(base.balanceOf(address(staking)), 3);
        assertEq(staking.stakeOf(address(this)).lastClaimedAt, block.number);
        assertEq(staking.stakeOf(address(this)).tokenIds[0], tokenIds[0]);
        assertEq(staking.stakeOf(address(this)).tokenIds[1], tokenIds[1]);
        assertEq(staking.stakeOf(address(this)).tokenIds[2], tokenIds[2]);
    }

    /// @dev Mints and attemps to stake 3 tokens, then 2 tokens across another
    /// call
    function testStakeTokensTwice() public {
        uint16[] memory tokenIds = new uint16[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;

        uint16[] memory moreTokenIds = new uint16[](2);
        moreTokenIds[0] = 3;
        moreTokenIds[1] = 4;

        base.mint(address(this), 5);

        base.setApprovalForAll(address(staking), true);

        staking.stakeTokens(tokenIds);

        vm.roll(block.number + 1);
        staking.stakeTokens(moreTokenIds);

        uint256 expected = (staking.emissionAmount() /
            staking.emissionFrequency()) * tokenIds.length;
        assertEq(emission.balanceOf(address(this)), expected);
        assertEq(base.balanceOf(address(this)), 0);
        assertEq(base.balanceOf(address(staking)), 5);
        assertEq(staking.stakeOf(address(this)).lastClaimedAt, block.number);
        assertEq(staking.stakeOf(address(this)).tokenIds[0], tokenIds[0]);
        assertEq(staking.stakeOf(address(this)).tokenIds[1], tokenIds[1]);
        assertEq(staking.stakeOf(address(this)).tokenIds[2], tokenIds[2]);
        assertEq(staking.stakeOf(address(this)).tokenIds[3], moreTokenIds[0]);
        assertEq(staking.stakeOf(address(this)).tokenIds[4], moreTokenIds[1]);
    }

    // ------------------------------ WITHDRAWALS ------------------------------

    /// @dev Mints and attemps to stake a single token, then tries to withdraw
    /// the stake after one full emission cycle
    function testWithdrawStakedToken() public {
        uint16[] memory tokenIds = new uint16[](1);
        tokenIds[0] = 0;

        base.mint(address(this), 1);

        base.setApprovalForAll(address(staking), true);

        staking.stakeTokens(tokenIds);

        vm.roll(block.number + staking.emissionFrequency());
        staking.withdrawStake();

        uint256 expected = (staking.emissionAmount() /
            staking.emissionFrequency()) *
            staking.emissionFrequency() *
            tokenIds.length;
        assertEq(emission.balanceOf(address(this)), expected);
        assertEq(base.balanceOf(address(this)), 1);
        assertEq(base.balanceOf(address(staking)), 0);
        assertEq(staking.stakeOf(address(this)).lastClaimedAt, 0);
        assertEq(staking.stakeOf(address(this)).tokenIds.length, 0);
    }

    /// @dev Mints and attemps to stake 3 tokens, then tries to withdraw the
    /// stake after one full emission cycle
    function testWithdrawStakedTokens() public {
        uint16[] memory tokenIds = new uint16[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;

        base.mint(address(this), 3);

        base.setApprovalForAll(address(staking), true);

        staking.stakeTokens(tokenIds);

        vm.roll(block.number + staking.emissionFrequency());
        staking.withdrawStake();

        uint256 expected = (staking.emissionAmount() /
            staking.emissionFrequency()) *
            staking.emissionFrequency() *
            tokenIds.length;
        assertEq(emission.balanceOf(address(this)), expected);
        assertEq(base.balanceOf(address(this)), 3);
        assertEq(base.balanceOf(address(staking)), 0);
        assertEq(staking.stakeOf(address(this)).lastClaimedAt, 0);
        assertEq(staking.stakeOf(address(this)).tokenIds.length, 0);
    }

    /// @dev Mints and attemps to stake 3 tokens, then 2 tokens across another
    /// call and then tries to withdraw the stake after one full emission cycle
    function testWithdrawTwiceStakedTokens() public {
        uint256 expected;

        uint16[] memory tokenIds = new uint16[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;

        uint16[] memory moreTokenIds = new uint16[](2);
        moreTokenIds[0] = 3;
        moreTokenIds[1] = 4;

        base.mint(address(this), 5);

        base.setApprovalForAll(address(staking), true);

        staking.stakeTokens(tokenIds);

        // Count 3 cycles (the next call to `stakeTokens` will automatically
        // claim rewards)
        expected +=
            (staking.emissionAmount() / staking.emissionFrequency()) *
            tokenIds.length;

        vm.roll(block.number + 1);
        staking.stakeTokens(moreTokenIds);

        vm.roll(block.number + staking.emissionFrequency() - 1);
        staking.withdrawStake();

        expected +=
            (staking.emissionAmount() / staking.emissionFrequency()) *
            (staking.emissionFrequency() - 1) *
            (moreTokenIds.length + tokenIds.length);
        assertEq(emission.balanceOf(address(this)), expected);
        assertEq(base.balanceOf(address(this)), 5);
        assertEq(base.balanceOf(address(staking)), 0);
        assertEq(staking.stakeOf(address(this)).lastClaimedAt, 0);
        assertEq(staking.stakeOf(address(this)).tokenIds.length, 0);
    }

    // -------------------------------- REWARDS --------------------------------

    /// @dev Mints and attemps to stake a single token then tries to claim
    /// rewards after one full emission cycle
    function testClaimFullRewardForToken() public {
        uint16[] memory tokenIds = new uint16[](1);
        tokenIds[0] = 0;

        base.mint(address(this), 1);

        base.setApprovalForAll(address(staking), true);

        staking.stakeTokens(tokenIds);

        vm.roll(block.number + staking.emissionFrequency());
        staking.claimReward();

        uint256 expected = (staking.emissionAmount() /
            staking.emissionFrequency()) *
            staking.emissionFrequency() *
            tokenIds.length;
        assertEq(emission.balanceOf(address(this)), expected);
        assertEq(staking.stakeOf(address(this)).lastClaimedAt, block.number);
    }

    /// @dev Mints and attemps to stake 3 tokens then tries to claim rewards
    /// after one full emission cycle
    function testClaimFullRewardForTokens() public {
        uint16[] memory tokenIds = new uint16[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;

        base.mint(address(this), 3);

        base.setApprovalForAll(address(staking), true);

        staking.stakeTokens(tokenIds);

        vm.roll(block.number + staking.emissionFrequency());
        staking.claimReward();

        uint256 expected = (staking.emissionAmount() /
            staking.emissionFrequency()) *
            staking.emissionFrequency() *
            tokenIds.length;
        assertEq(emission.balanceOf(address(this)), expected);
        assertEq(staking.stakeOf(address(this)).lastClaimedAt, block.number);
    }

    /// @dev Mints and attemps to stake 3 tokens, then 2 tokens across another
    /// call then tries to claim rewards after one full emission cycle
    function testClaimFullRewardForTwiceStakedTokens() public {
        uint256 expected;

        uint16[] memory tokenIds = new uint16[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;

        uint16[] memory moreTokenIds = new uint16[](2);
        moreTokenIds[0] = 3;
        moreTokenIds[1] = 4;

        base.mint(address(this), 5);

        base.setApprovalForAll(address(staking), true);

        staking.stakeTokens(tokenIds);

        // Count 3 cycles (the next call to `stakeTokens` will automatically
        // claim rewards)
        expected +=
            (staking.emissionAmount() / staking.emissionFrequency()) *
            tokenIds.length;

        vm.roll(block.number + 1);
        staking.stakeTokens(moreTokenIds);

        vm.roll(block.number + staking.emissionFrequency() - 1);
        staking.claimReward();

        expected +=
            (staking.emissionAmount() / staking.emissionFrequency()) *
            (staking.emissionFrequency() - 1) *
            (moreTokenIds.length + tokenIds.length);
        assertEq(emission.balanceOf(address(this)), expected);
        assertEq(staking.stakeOf(address(this)).lastClaimedAt, block.number);
    }

    /// @dev Mints and attemps to stake a single token then tries to claim
    /// rewards after half of an emission cycle
    function testClaimPartialRewardForToken() public {
        uint16[] memory tokenIds = new uint16[](1);
        tokenIds[0] = 0;

        base.mint(address(this), 1);

        base.setApprovalForAll(address(staking), true);

        staking.stakeTokens(tokenIds);

        vm.roll(block.number + staking.emissionFrequency() / 2);
        staking.claimReward();

        uint256 expected = ((staking.emissionAmount() /
            staking.emissionFrequency()) *
            staking.emissionFrequency() *
            tokenIds.length) / 2;
        assertEq(emission.balanceOf(address(this)), expected);
        assertEq(staking.stakeOf(address(this)).lastClaimedAt, block.number);
    }

    /// @dev Mints and attemps to stake 3 tokens then tries to claim rewards
    /// after half of an emission cycle
    function testClaimPartialRewardForTokens() public {
        uint16[] memory tokenIds = new uint16[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;

        base.mint(address(this), 3);

        base.setApprovalForAll(address(staking), true);

        staking.stakeTokens(tokenIds);

        vm.roll(block.number + staking.emissionFrequency() / 2);
        staking.claimReward();

        uint256 expected = ((staking.emissionAmount() /
            staking.emissionFrequency()) *
            staking.emissionFrequency() *
            tokenIds.length) / 2;
        assertEq(emission.balanceOf(address(this)), expected);
        assertEq(staking.stakeOf(address(this)).lastClaimedAt, block.number);
        assertEq(staking.stakeOf(address(this)).tokenIds.length, 3);
    }

    /// @dev Mints and attemps to stake 3 tokens, then 2 tokens across another
    /// call then tries to claim rewards after half of an emission cycle
    function testClaimPartialRewardForTwiceStakedTokens() public {
        uint256 expected;

        uint16[] memory tokenIds = new uint16[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;

        uint16[] memory moreTokenIds = new uint16[](2);
        moreTokenIds[0] = 3;
        moreTokenIds[1] = 4;

        base.mint(address(this), 5);

        base.setApprovalForAll(address(staking), true);

        staking.stakeTokens(tokenIds);

        // Count 3 cycles (the next call to `stakeTokens` will automatically
        // claim rewards)
        expected +=
            (staking.emissionAmount() / staking.emissionFrequency()) *
            tokenIds.length;

        vm.roll(block.number + 1);
        staking.stakeTokens(moreTokenIds);

        vm.roll(block.number + staking.emissionFrequency() / 2);
        staking.claimReward();

        expected +=
            (staking.emissionAmount() / staking.emissionFrequency()) *
            (staking.emissionFrequency() / 2) *
            (moreTokenIds.length + tokenIds.length);
        assertEq(emission.balanceOf(address(this)), expected);
        assertEq(staking.stakeOf(address(this)).lastClaimedAt, block.number);
    }

    /// @dev Attempts to claim rewards with no tokens staked
    function testClaimNoReward() public {
        uint16[] memory tokenIds = new uint16[](1);
        tokenIds[0] = 0;

        base.mint(address(this), 1);

        base.setApprovalForAll(address(staking), true);

        staking.stakeTokens(tokenIds);

        staking.claimReward();

        assertEq(emission.balanceOf(address(this)), 0);
    }

    // ------------------------- REVERSIONS/EDGE CASES -------------------------

    /// @dev Mints 2 tokens to itself, a single token to a dead address then
    /// tries to stake all tokens
    function testCannotStakeNonOwnedTokens() public {
        uint16[] memory tokenIds = new uint16[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;

        base.mint(address(this), 2);
        base.mint(address(0xDEAD), 1);

        base.setApprovalForAll(address(staking), true);

        vm.expectRevert(
            bytes("ERC721: transfer caller is not owner nor approved")
        );
        staking.stakeTokens(tokenIds);
    }

    /// @dev Mints 3 tokens to itself, 2 token to a dead address then tries
    /// to stake all tokens over 2 calls
    function testCannotTwiceStakeNonOwnedTokens() public {
        uint16[] memory tokenIds = new uint16[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;

        uint16[] memory moreTokenIds = new uint16[](2);
        moreTokenIds[0] = 3;
        moreTokenIds[1] = 4;

        base.mint(address(this), 3);
        base.mint(address(0xDEAD), 2);

        base.setApprovalForAll(address(staking), true);

        staking.stakeTokens(tokenIds);

        vm.expectRevert(
            bytes("ERC721: transfer caller is not owner nor approved")
        );
        staking.stakeTokens(moreTokenIds);
    }

    /// @dev Mints a single token then tries to send it to the staking contract
    /// via the {ERC721-safeTransferFrom} function
    function testCannotSendTokensToStakingContract() public {
        base.mint(address(this), 1);

        vm.expectRevert(bytes("Staking: please refer to staking.example.com"));
        base.safeTransferFrom(address(this), address(staking), 0);
    }

    /// @dev Attempts to stake an empty array of token IDs
    function testCannotStakeNoTokens() public {
        uint16[] memory tokenIds;

        vm.expectRevert(bytes("Staking: must be staking more than 0 tokens"));
        staking.stakeTokens(tokenIds);
    }

    /// @dev Attempts to withdraw stake with no staked tokens
    function testCannotWithdrawWithNoStakedTokens() public {
        vm.expectRevert("Staking: you have no tokens staked");
        staking.withdrawStake();
    }

    // ------------------------------ OWNER ONLY ------------------------------

    /// @dev Attempts to withdraw all emission tokens from the contract as the
    /// owner
    function testWithdrawEmissionTokens() public {
        staking.withdrawTokens(type(uint256).max);

        assertEq(emission.balanceOf(address(this)), type(uint256).max);
    }
}
