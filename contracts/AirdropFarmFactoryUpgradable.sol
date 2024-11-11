// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./AirdropFarmingPoolUpgradable.sol";

contract AirdropFarmFactoryUpgradeable is Initializable, UUPSUpgradeable, AccessControlUpgradeable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    address[] public farms;

    event FarmCreated(address indexed farmAddress, string farmName);

    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(ADMIN_ROLE) {}

    function createFarm(
        string calldata _farmName,
        ERC20Upgradeable _acceptedToken,
        uint256 _baseRate,
        uint256 _timeLockedMultiplier,
        uint256 _donationMultiplier
    ) external onlyRole(ADMIN_ROLE) returns (address) {
        AirdropFarmingPoolUpgradeable farm = new AirdropFarmingPoolUpgradeable();
        farm.initialize(
            _acceptedToken,
            _baseRate,
            _timeLockedMultiplier,
            _donationMultiplier
        );

        farms.push(address(farm));
        emit FarmCreated(address(farm), _farmName);
        return address(farm);
    }

    function getFarms() external view returns (address[] memory) {
        return farms;
    }

    function grantAdminRole(address newAdmin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(ADMIN_ROLE, newAdmin);
    }

    function revokeAdminRole(address admin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(ADMIN_ROLE, admin);
    }
}