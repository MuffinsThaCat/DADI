const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  try {
    console.log(`Deploying DADI Auction contract to ${hre.network.name} network...`);

    // Get the contract factory
    const DADIAuction = await hre.ethers.getContractFactory("DADIAuction");
    
    // Deploy the contract
    console.log("Deploying contract...");
    const dadiAuction = await DADIAuction.deploy();
    
    // Wait for deployment to complete
    console.log("Waiting for deployment transaction...");
    await dadiAuction.deployed();
    console.log(`DADIAuction deployed to: ${dadiAuction.address}`);

    // Wait for confirmations based on network
    const confirmations = ["hardhat", "localhost"].includes(hre.network.name) ? 1 : 5;
    console.log(`Waiting for ${confirmations} block confirmations...`);
    await dadiAuction.deployTransaction.wait(confirmations);
    console.log("Deployment confirmed!");

    // Verify the contract on Etherscan for supported networks
    const supportedNetworks = ["sepolia", "mainnet", "polygon", "mumbai"];
    if (process.env.ETHERSCAN_API_KEY && supportedNetworks.includes(hre.network.name)) {
      console.log("Verifying contract on Etherscan...");
      try {
        await hre.run("verify:verify", {
          address: dadiAuction.address,
          constructorArguments: [],
        });
        console.log("Contract verified on Etherscan!");
      } catch (error) {
        console.error("Error verifying contract:", error.message);
        console.log("You may need to verify the contract manually.");
      }
    }

    // Save the contract address and deployment info
    saveDeploymentInfo(hre.network.name, dadiAuction.address);
    
    // Update the contract address in the Flutter app
    updateContractAddress(dadiAuction.address);
    
    console.log("Deployment completed successfully!");
    return dadiAuction.address;
  } catch (error) {
    console.error("Deployment failed:", error);
    process.exit(1);
  }
}

function saveDeploymentInfo(networkName, contractAddress) {
  const deploymentInfo = {
    network: networkName,
    address: contractAddress,
    timestamp: new Date().toISOString()
  };

  const deploymentPath = path.join(__dirname, "..", "deployments");
  if (!fs.existsSync(deploymentPath)) {
    fs.mkdirSync(deploymentPath);
  }

  const filePath = path.join(deploymentPath, `${networkName}.json`);
  fs.writeFileSync(
    filePath,
    JSON.stringify(deploymentInfo, null, 2)
  );

  console.log("Deployment info saved to:", filePath);
}

function updateContractAddress(contractAddress) {
  try {
    // Path to the deployment.json file used by the Flutter app
    const deploymentJsonPath = path.join(__dirname, "..", "deployment.json");
    
    // Read existing file if it exists, or create new object
    let deploymentJson = {};
    if (fs.existsSync(deploymentJsonPath)) {
      const fileContent = fs.readFileSync(deploymentJsonPath, 'utf8');
      deploymentJson = JSON.parse(fileContent);
    }
    
    // Update with new contract address
    deploymentJson.contractAddress = contractAddress;
    deploymentJson.lastUpdated = new Date().toISOString();
    
    // Write back to file
    fs.writeFileSync(
      deploymentJsonPath,
      JSON.stringify(deploymentJson, null, 2)
    );
    
    console.log("Contract address updated in deployment.json for Flutter app");
  } catch (error) {
    console.error("Error updating contract address in Flutter app:", error.message);
  }
}

// Execute the deployment
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

// Export for testing
module.exports = { main };
