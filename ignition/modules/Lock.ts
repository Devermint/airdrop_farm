import { ethers, upgrades } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`Deploying contracts with deployer: ${deployer.address}`);

  // Deploy the AirdropFarmFactoryUpgradeable as a UUPS proxy
  const Factory = await ethers.getContractFactory("AirdropFarmFactoryUpgradeable");
  const factory = await upgrades.deployProxy(Factory, [], {
    kind: "uups",
    initializer: "initialize",
  });

  await factory.deployed();

  console.log(`AirdropFarmFactoryUpgradeable deployed at: ${factory.address}`);

  // Fetch the implementation address
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(factory.address);
  console.log(`AirdropFarmFactoryUpgradeable implementation deployed at: ${implementationAddress}`);
}

// Execute the script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
