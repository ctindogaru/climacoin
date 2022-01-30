// contracts/TokenVesting.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title TokenVesting
 * @dev A token holder contract that can release its token balance gradually like a
 * typical vesting scheme.
 */
contract TokenVesting {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event TokensReleased(uint256 amount);

    // owner of this contract
    address private _owner;
    // beneficiary of tokens after they are released
    address private _beneficiary;

    // Durations and timestamps are expressed in UNIX time, the same units as block.timestamp.
    uint256 private _start;
    uint256 private _cliff;
    uint256 private _finish;
    uint256 private _duration;
    uint256 private _releasesCount;
    uint256 private _released;

    IERC20 private _token;

    /**
     * @dev Creates a vesting contract that vests its balance of any ERC20 token to the
     * beneficiary, gradually in a linear fashion until block.timestamp + cliff + duration * releasesCount.
     * By then all of the balance will have vested.
     * @param __token address of the token which should be vested
     * @param __beneficiary address of the beneficiary to whom vested tokens are transferred
     * @param __cliff the duration in seconds from the current time at which point vesting starts
     * @param __duration duration in seconds of each release
     * @param __releasesCount total amount of upcoming releases
     */
    constructor(
        address __token,
        address __beneficiary,
        uint256 __cliff,
        uint256 __duration,
        uint256 __releasesCount
    ) {
        require(
            __token != address(0),
            "TokenVesting: token is the zero address!"
        );
        require(
            __beneficiary != address(0),
            "TokenVesting: beneficiary is the zero address!"
        );
        require(__cliff > 0, "TokenVesting: cliff is 0!");
        require(__duration > 0, "TokenVesting: duration is 0!");
        require(__releasesCount > 0, "TokenVesting: releases count is 0!");

        _token = IERC20(__token);
        _beneficiary = __beneficiary;
        _duration = __duration;
        _releasesCount = __releasesCount;
        _cliff = __cliff;
        _start = block.timestamp.add(__cliff);
        _finish = _start.add(_releasesCount.mul(_duration));

        _owner = msg.sender;
    }

    // -----------------------------------------------------------------------
    // GETTERS
    // -----------------------------------------------------------------------

    /**
     * @return the beneficiary of the tokens.
     */
    function beneficiary() public view returns (address) {
        return _beneficiary;
    }

    /**
     * @return the start time of the token vesting.
     */
    function start() public view returns (uint256) {
        return _start;
    }

    /**
     * @return the cliff of the token vesting.
     */
    function cliff() public view returns (uint256) {
        return _cliff;
    }

    /**
     * @return the finish time of the token vesting.
     */
    function finish() public view returns (uint256) {
        return _finish;
    }

    /**
     * @return the duration of the token vesting.
     */
    function duration() public view returns (uint256) {
        return _duration;
    }

    /**
     * @return the amount of the token released.
     */
    function released() public view returns (uint256) {
        return _released;
    }

    /**
     * @return the number of token releases.
     */
    function releasesCount() public view returns (uint256) {
        return _releasesCount;
    }

    /**
     * @return owner of this vesting contract.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    function getAvailableTokens() public view returns (uint256) {
        return _releasableAmount();
    }

    // -----------------------------------------------------------------------
    // SETTERS
    // -----------------------------------------------------------------------

    /**
     * @notice Transfers vested tokens to beneficiary.
     */
    function release() public {
        require(msg.sender == _beneficiary, "release: unauthorized sender!");

        uint256 unreleased = _releasableAmount();
        require(unreleased > 0, "release: No tokens are due!");

        _released = _released.add(unreleased);
        _token.safeTransfer(_beneficiary, unreleased);

        emit TokensReleased(unreleased);
    }

    // -----------------------------------------------------------------------
    // INTERNAL
    // -----------------------------------------------------------------------

    /**
     * @dev Calculates the amount that has already vested but hasn't been released yet.
     */
    function _releasableAmount() private view returns (uint256) {
        return _vestedAmount().sub(_released);
    }

    /**
     * @dev Calculates the amount that has already vested.
     */
    function _vestedAmount() private view returns (uint256) {
        uint256 currentBalance = _token.balanceOf(address(this));
        uint256 totalBalance = currentBalance.add(_released);

        if (block.timestamp < _start) {
            return 0;
        } else if (block.timestamp >= _finish) {
            return totalBalance;
        } else {
            uint256 timeLeftAfterStart = block.timestamp.sub(_start);
            uint256 availableReleases = timeLeftAfterStart.div(_duration);
            uint256 tokensPerRelease = totalBalance.div(_releasesCount);

            return availableReleases.mul(tokensPerRelease);
        }
    }
}
