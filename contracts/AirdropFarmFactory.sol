// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./AirdropFarmingPool.sol";

contract AirdropFarmFactory is Ownable {
    address[] public farms;

    event FarmCreated(address indexed farmAddress, string farmName);

    constructor() Ownable(msg.sender) {

    }

    function createFarm(
        string calldata _farmName,
        IERC20 _acceptedToken,
        IERC721 _acceptedLP,
        uint256 _baseRate,
        uint256 _timeLockedMultiplier,
        uint256 _donationMultiplier
    ) external onlyOwner returns (address) {
        AirdropFarmingPool farm = new AirdropFarmingPool(_acceptedToken,
            _acceptedLP,
            _baseRate,
            _timeLockedMultiplier,
            _donationMultiplier,
            msg.sender);

        farms.push(address(farm));
        emit FarmCreated(address(farm), _farmName);
        return address(farm);
    }

    function getFarms() external view returns (address[] memory) {
        return farms;
    }
}
