const fs = require('fs');
const path = require('path');

// Get the network name from command line arguments
const networkName = process.argv[2] || 'localhost';

// Paths
const rootDir = path.join(__dirname, '..');
const deploymentsDir = path.join(rootDir, 'deployments');
const deploymentJsonPath = path.join(rootDir, 'deployment.json');
const dartContractPath = path.join(rootDir, 'lib', 'contracts', 'dadi_auction.dart');

// Check if the deployment file exists
const deploymentFilePath = path.join(deploymentsDir, `${networkName}.json`);
if (!fs.existsSync(deploymentFilePath)) {
  console.error(`Error: Deployment file for network '${networkName}' not found.`);
  console.error(`Expected file at: ${deploymentFilePath}`);
  console.error('Please deploy the contract first using: npx hardhat run --network <network> scripts/deploy.js');
  process.exit(1);
}

// Read the deployment file
const deploymentData = JSON.parse(fs.readFileSync(deploymentFilePath, 'utf8'));
const contractAddress = deploymentData.address;

console.log(`Found contract address for network '${networkName}': ${contractAddress}`);

// Update the deployment.json file used by the Flutter app
let deploymentJson = {};
if (fs.existsSync(deploymentJsonPath)) {
  deploymentJson = JSON.parse(fs.readFileSync(deploymentJsonPath, 'utf8'));
}

deploymentJson.contractAddress = contractAddress;
deploymentJson.network = networkName;
deploymentJson.lastUpdated = new Date().toISOString();

fs.writeFileSync(
  deploymentJsonPath,
  JSON.stringify(deploymentJson, null, 2)
);

console.log(`Updated deployment.json with contract address: ${contractAddress}`);

// Check if the Dart contract file exists and update it if needed
if (fs.existsSync(dartContractPath)) {
  let dartContractContent = fs.readFileSync(dartContractPath, 'utf8');
  
  // Look for the address field in the Dart file
  const addressRegex = /static const String address = ['"]([^'"]+)['"]/;
  const match = dartContractContent.match(addressRegex);
  
  if (match) {
    // Replace the address with the new one
    dartContractContent = dartContractContent.replace(
      addressRegex,
      `static const String address = '${contractAddress}'`
    );
    
    fs.writeFileSync(dartContractPath, dartContractContent);
    console.log(`Updated contract address in Dart file: ${dartContractPath}`);
  } else {
    console.warn('Could not find address field in Dart contract file. Manual update may be required.');
  }
} else {
  console.warn(`Dart contract file not found at: ${dartContractPath}`);
}

console.log('Contract address update completed successfully!');
