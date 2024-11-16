// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AirdropFarmingPool is Ownable, ReentrancyGuard {
    IERC20 public acceptedToken;
    IERC721 public acceptedLP;
    uint256 public baseRate;
    uint256 public timeLockedMultiplier;
    uint256 public donationMultiplier;
    uint256 public mainnetLaunchMultiplier; //
    uint256 public kycMultiplier;
    uint256 public referralMultiplier;
    bool public paused;
    address[] public usersList;
    bool public mainnetLaunched;
    uint256 public totalCredits;

    struct LockInfo {
        uint256 amount;
        uint256 lockType;
        bool boostedDonation;
        uint256 lastUpdatedTime;
        uint256 cumulativeCredits;
        uint256 referralMultiplier;
    }

    mapping(address => LockInfo) public lockedTokens;

    event TokensLocked(address indexed user, uint256 amount, uint256 lockType);
    event TokensBoosted(address indexed user, uint256 newCredits);
    event TokensWithdrawn(address indexed user, uint256 amount);
    event BoostParametersUpdated(uint256 timeLockedMultiplier, uint256 donationMultiplier);
    event PoolPaused();
    event PoolResumed();
    event MainnetLaunched(bool launched);

    constructor(
        IERC20 _acceptedToken,
        IERC721 _acceptedLP,
        uint256 _baseRate,
        uint256 _timeLockedMultiplier,
        uint256 _donationMultiplier,
        address _admin
    ) Ownable(_admin) {
        acceptedToken = _acceptedToken;
        acceptedLP = _acceptedLP;
        baseRate = _baseRate;
        timeLockedMultiplier = _timeLockedMultiplier;
        donationMultiplier = _donationMultiplier;
        paused = false;
    }

    modifier onlyWhenNotPaused() {
        require(!paused, "Pool is paused");
        _;
    }

    function pause() external onlyOwner {
        paused = true;
        emit PoolPaused();
    }

    function resume() external onlyOwner {
        paused = false;
        emit PoolResumed();
    }

    function setMainnetLaunched(bool _launched) external onlyOwner {
        mainnetLaunched = _launched;
        emit MainnetLaunched(_launched);
    }

    function lockTokens(uint256 amount, uint256 lockType) external nonReentrant onlyWhenNotPaused { //TO DO donation here! parameter -> update
        require(amount > 0, "Amount must be greater than zero");
        require(lockType == 0 || lockType == 1, "Invalid lock type");

        if (lockedTokens[msg.sender].amount == 0) {
            usersList.push(msg.sender);
        }
        acceptedToken.transferFrom(msg.sender, address(this), amount);
        LockInfo storage lockInfo = lockedTokens[msg.sender];
        updateCredits(msg.sender);
        lockInfo.amount += amount;
        lockInfo.lockType = lockType;
        lockInfo.lastUpdatedTime = block.timestamp;

        emit TokensLocked(msg.sender, amount, lockType);
    }

    function boostAirdrop() external nonReentrant onlyWhenNotPaused { //Boost selected amount
        LockInfo storage lockInfo = lockedTokens[msg.sender];
        require(lockInfo.amount > 0, "No tokens locked");
        require(!lockInfo.boostedDonation, "Already boosted");

        updateCredits(msg.sender);
        lockInfo.boostedDonation = true;

        emit TokensBoosted(msg.sender, lockInfo.cumulativeCredits);
    }

    function viewCredits(address user) external view returns (uint256) {
        LockInfo storage lockInfo = lockedTokens[user];
        if (lockInfo.amount == 0) return lockInfo.cumulativeCredits;

        uint256 timeElapsed = block.timestamp - lockInfo.lastUpdatedTime;
        uint256 multiplier = lockInfo.lockType == 1 ? timeLockedMultiplier : 1;
        if (lockInfo.boostedDonation) multiplier += donationMultiplier;

        return lockInfo.cumulativeCredits + (timeElapsed * lockInfo.amount * baseRate * multiplier);
    }

    function getUserLockedTokens(address user) external view returns (uint256) {
    LockInfo storage lockInfo = lockedTokens[user];
    return lockInfo.amount;
    }

    function getTotalLockedTokens() external view returns (uint256 totalLocked) {
        totalLocked = 0;
        for (uint256 i = 0; i < usersList.length; i++) {
            address user = usersList[i];
            LockInfo storage lockInfo = lockedTokens[user];
            totalLocked += lockInfo.amount;
        }
    }

    function withdrawTokens() external nonReentrant onlyWhenNotPaused { //boosted donation problem
        LockInfo storage lockInfo = lockedTokens[msg.sender];
        require(lockInfo.amount > 0, "No tokens to withdraw");
        require(!lockInfo.boostedDonation, "Cannot withdraw boosted tokens");

        updateCredits(msg.sender);

        uint256 amountToWithdraw = lockInfo.amount;
        lockInfo.amount = 0;

        acceptedToken.transfer(msg.sender, amountToWithdraw);

        emit TokensWithdrawn(msg.sender, amountToWithdraw);
    }

    function updateCredits(address user) internal {
        LockInfo storage lockInfo = lockedTokens[user];
        if (lockInfo.amount == 0) return;

        uint256 timeElapsed = block.timestamp - lockInfo.lastUpdatedTime;
        uint256 multiplier = lockInfo.lockType == 1 ? timeLockedMultiplier : 1;
        if (lockInfo.boostedDonation) multiplier += donationMultiplier;

        uint256 newCredits = timeElapsed * lockInfo.amount * baseRate * multiplier;
        totalCredits += newCredits;
        lockInfo.cumulativeCredits += newCredits;
        lockInfo.lastUpdatedTime = block.timestamp;
    }

    function updateGlobalBoostParameters(
        uint256 _baseRate,
        uint256 _timeLockedMultiplier,
        uint256 _donationMultiplier
    ) external onlyOwner {
        baseRate = _baseRate;
        timeLockedMultiplier = _timeLockedMultiplier;
        donationMultiplier = _donationMultiplier;

        emit BoostParametersUpdated(_timeLockedMultiplier, _donationMultiplier);
    }

    function updateReferralMultiplier(address user, uint256 referralRate) external onlyOwner {
    require(user != address(0), "Invalid user address");
    require(lockedTokens[user].amount > 0, "User has no locked tokens");
    lockedTokens[user].referralMultiplier = referralRate;
    }

    function rescueERC20(address tokenAddress, uint256 amount) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(address(this)) >= amount, "Insufficient balance");
        token.transfer(msg.sender, amount);
    }

    function rescueNative(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");
        payable(msg.sender).transfer(amount);
    }

    receive() external payable {}
}