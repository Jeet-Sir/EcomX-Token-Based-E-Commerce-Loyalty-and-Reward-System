const hre = require("hardhat");

async function main() {
  const EcomXToken = await hre.ethers.getContractFactory("EcomXToken");
  const ecomx = await EcomXToken.deploy();
  await ecomx.deployed();

  console.log("EcomXToken deployed to:", ecomx.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
