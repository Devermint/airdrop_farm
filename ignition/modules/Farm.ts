import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { ethers, upgrades } from "hardhat";
import { Contract } from "ethers";

export default buildModule("AirdropFarmFactoryUpgradeable", (m) => {
  // Deploy the AirdropFarmFactoryUpgradeable
  const factory = m.contract("AirdropFarmFactoryUpgradeable", []);

  // Initialize the factory contract
  m.call(factory, "initialize", []);

  return { factory };

  // Optional: Assign roles, deploy more contracts, interact as needed.
  // For example, grant admin role to another address:
  // const newAdmin = "0xNewAdminAddress";
  // await m.call(factory, "grantAdminRole", [newAdmin]);
});
