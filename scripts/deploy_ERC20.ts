import { ethers } from "hardhat";

async function main() {
  const ExampleERC20 = await ethers.getContractFactory("ExampleERC20");
  const exampleERC20 = await ExampleERC20.deploy();

  await exampleERC20.deployed();

  console.log(`Deployed to ${exampleERC20.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
