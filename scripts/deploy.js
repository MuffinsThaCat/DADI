const hre = require("hardhat");

async function main() {
  console.log("Deploying DADI Auction contract...");

  // Deploy the contract
  const DADIAuction = await hre.ethers.getContractFactory("DADIAuction");
  const dadiAuction = await DADIAuction.deploy();
  await dadiAuction.deployed();

  console.log(`DADIAuction deployed to: ${dadiAuction.address}`);

  // Wait for fewer confirmations on local network
  const confirmations = hre.network.name === "localhost" ? 1 : 5;
  console.log(`Waiting for ${confirmations} block confirmations...`);
  await dadiAuction.deployTransaction.wait(confirmations);

  // Verify the contract on Etherscan
  if (process.env.ETHERSCAN_API_KEY && hre.network.name !== "hardhat" && hre.network.name !== "localhost") {
    console.log("Verifying contract on Etherscan...");
    await hre.run("verify:verify", {
      address: dadiAuction.address,
      constructorArguments: [],
    });
    console.log("Contract verified on Etherscan!");
  }

  // Save the contract address to a file
  const fs = require("fs");
  const deploymentInfo = {
    network: hre.network.name,
    address: dadiAuction.address,
    timestamp: new Date().toISOString()
  };

  const deploymentPath = "./deployments";
  if (!fs.existsSync(deploymentPath)) {
    fs.mkdirSync(deploymentPath);
  }

  fs.writeFileSync(
    `${deploymentPath}/${hre.network.name}.json`,
    JSON.stringify(deploymentInfo, null, 2)
  );

  console.log("Deployment info saved to:", `${deploymentPath}/${hre.network.name}.json`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
