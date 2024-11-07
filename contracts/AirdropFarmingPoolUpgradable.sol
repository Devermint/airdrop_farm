// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract AirdropFarmingPoolUpgradeable is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    ERC20Upgradeable public acceptedToken;
    uint256 public baseRate;
    uint256 public timeLockedMultiplier;
    uint256 public donationMultiplier;
    uint256 public mainnetLaunchMultiplier;
    bool public paused;
    address private newOwner;
    address[] public usersList;
    bool public mainnetLaunched;

    struct LockInfo {
        uint256 amount;
        uint256 lockType;
        bool boostedDonation;
        uint256 lastUpdatedTime;
        uint256 totalCredits;
        uint256 cumulativeCredits;
    }

    mapping(address => LockInfo) public lockedTokens;

    event TokensLocked(address indexed user, uint256 amount, uint256 lockType);
    event TokensBoosted(address indexed user, uint256 newCredits);
    event TokensWithdrawn(address indexed user, uint256 amount);
    event BoostParametersUpdated(
        uint256 timeLockedMultiplier,
        uint256 donationMultiplier
    );
    event PoolPaused();
    event PoolResumed();
    event MainnetLaunched(bool launched);

    constructor() {
        _disableInitializers();
    }

    function initialize(
        ERC20Upgradeable _acceptedToken,
        uint256 _baseRate,
        uint256 _timeLockedMultiplier,
        uint256 _donationMultiplier
    ) public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        acceptedToken = _acceptedToken;
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

    function lockTokens(
        uint256 amount,
        uint256 lockType
    ) external nonReentrant onlyWhenNotPaused {
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

    function boostAirdrop() external nonReentrant onlyWhenNotPaused {
        LockInfo storage lockInfo = lockedTokens[msg.sender];
        require(lockInfo.amount > 0, "No tokens locked");
        require(lockInfo.boostedDonation == true, "Already boosted");

        updateCredits(msg.sender);
        lockInfo.boostedDonation = true;

        emit TokensBoosted(msg.sender, lockInfo.totalCredits);
    }

    function viewCredits(address user) external view returns (uint256) {
        LockInfo storage lockInfo = lockedTokens[user];
        if (lockInfo.amount == 0) return lockInfo.totalCredits;

        uint256 timeElapsed = block.timestamp - lockInfo.lastUpdatedTime;
        uint256 multiplier = lockInfo.lockType == 1 ? timeLockedMultiplier : 1;
        if (lockInfo.boostedDonation == true) multiplier += donationMultiplier;

        return
            lockInfo.totalCredits +
            (timeElapsed * lockInfo.amount * baseRate * multiplier);
    }

    function getTotalLockedTokens()
        external
        view
        returns (uint256 totalLocked)
    {
        totalLocked = 0;

        for (uint256 i = 0; i < usersList.length; i++) {
            address user = usersList[i];
            LockInfo storage lockInfo = lockedTokens[user];
            totalLocked += lockInfo.amount;
        }
        return totalLocked;
    }

    function withdrawTokens() external nonReentrant onlyWhenNotPaused {
        LockInfo storage lockInfo = lockedTokens[msg.sender];
        require(lockInfo.amount > 0, "No tokens to withdraw");
        require(
            lockInfo.boostedDonation == false,
            "Cannot withdraw boosted tokens"
        );

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
        if (lockInfo.boostedDonation == true) multiplier += donationMultiplier;

        uint256 newCredits = timeElapsed *
            lockInfo.amount *
            baseRate *
            multiplier;
        lockInfo.totalCredits += newCredits;
        lockInfo.cumulativeCredits += newCredits;
        lockInfo.lastUpdatedTime = block.timestamp;
    }

    function updateGlobalBoostParameters(
        uint256 _timeLockedMultiplier,
        uint256 _donationMultiplier
    ) external onlyOwner {
        timeLockedMultiplier = _timeLockedMultiplier;
        donationMultiplier = _donationMultiplier;

        emit BoostParametersUpdated(_timeLockedMultiplier, _donationMultiplier);
    }

    function updateUserBoostParameters(
        address user,
        uint256 lockType,
        bool boostedDonation
    ) external onlyOwner {
        require(lockType == 0 || lockType == 1, "Invalid lock type");
        require(
            boostedDonation == false || boostedDonation == true,
            "Invalid boost value"
        );

        LockInfo storage lockInfo = lockedTokens[user];
        updateCredits(user);

        lockInfo.lockType = lockType;
        lockInfo.boostedDonation = boostedDonation;
    }

    function adminWithdrawBoostedTokens(uint256 amount) external onlyOwner {
        uint256 totalBoostedTokens = 0;

        for (uint256 i = 0; i < usersList.length; i++) {
            address user = usersList[i];
            LockInfo storage lockInfo = lockedTokens[user];

            if (lockInfo.boostedDonation = true) {
                totalBoostedTokens += lockInfo.totalCredits;
            }
        }

        require(
            totalBoostedTokens >= amount,
            "Insufficient boosted tokens available"
        );
        require(amount > 0, "Cannot withdraw zero tokens");

        uint256 remainingAmount = amount;

        for (uint256 i = 0; i < usersList.length; i++) {
            address user = usersList[i];
            LockInfo storage lockInfo = lockedTokens[user];

            if (lockInfo.boostedDonation == true && remainingAmount > 0) {
                uint256 toWithdraw = lockInfo.totalCredits > remainingAmount
                    ? remainingAmount
                    : lockInfo.totalCredits;
                lockInfo.totalCredits -= toWithdraw;
                remainingAmount -= toWithdraw;

                if (remainingAmount == 0) {
                    break;
                }
            }
        }
        acceptedToken.transfer(msg.sender, amount);
    }

    function rescueERC20(
        address tokenAddress,
        uint256 amount
    ) external onlyOwner {
        ERC20Upgradeable token = ERC20Upgradeable(tokenAddress);
        require(
            token.balanceOf(address(this)) >= amount,
            "Insufficient balance"
        );
        token.transfer(msg.sender, amount);
    }

    function rescueNative(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");
        payable(msg.sender).transfer(amount);
    }

    receive() external payable {}
}
