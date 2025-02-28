const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

// Paths
const rootDir = path.join(__dirname, '..');
const deploymentJsonPath = path.join(rootDir, 'deployment.json');

// Colors for console output
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
};

// Helper to log with colors
function log(message, color = colors.reset) {
  console.log(`${color}${message}${colors.reset}`);
}

// Execute a command and return a promise
function executeCommand(command, args, options = {}) {
  return new Promise((resolve, reject) => {
    log(`Executing: ${command} ${args.join(' ')}`, colors.cyan);
    
    const childProcess = spawn(command, args, {
      cwd: rootDir,
      stdio: 'inherit',
      shell: true,
      ...options
    });

    childProcess.on('close', (code) => {
      if (code === 0 || options.ignoreError) {
        resolve();
      } else {
        reject(new Error(`Command failed with exit code ${code}`));
      }
    });

    childProcess.on('error', (error) => {
      reject(error);
    });
  });
}

// Start the local Hardhat node
async function startHardhatNode() {
  log('Starting local Hardhat node...', colors.bright + colors.blue);
  
  // Use spawn to start the node in the background
  const hardhatNode = spawn('npx', ['hardhat', 'node'], {
    cwd: rootDir,
    stdio: 'pipe',
    shell: true,
    detached: true
  });

  // Handle output to detect when the node is ready
  return new Promise((resolve) => {
    let isReady = false;
    
    hardhatNode.stdout.on('data', (data) => {
      const output = data.toString();
      process.stdout.write(colors.yellow + output + colors.reset);
      
      // Check if the node is ready
      if (!isReady && output.includes('Started HTTP and WebSocket JSON-RPC server at')) {
        isReady = true;
        log('Hardhat node is running!', colors.bright + colors.green);
        resolve(hardhatNode);
      }
    });
    
    hardhatNode.stderr.on('data', (data) => {
      process.stderr.write(colors.red + data.toString() + colors.reset);
    });
    
    // Safety timeout after 10 seconds
    setTimeout(() => {
      if (!isReady) {
        log('Hardhat node seems to be taking a while, but continuing anyway...', colors.yellow);
        resolve(hardhatNode);
      }
    }, 10000);
  });
}

// Deploy the contract to the local node
async function deployContract() {
  log('Deploying smart contract to local node...', colors.bright + colors.blue);
  try {
    await executeCommand('npx', ['hardhat', 'run', '--network', 'localhost', 'scripts/deploy.js']);
    log('Contract deployed successfully!', colors.bright + colors.green);
    
    // Verify the deployment.json file was created
    if (fs.existsSync(deploymentJsonPath)) {
      const deploymentData = JSON.parse(fs.readFileSync(deploymentJsonPath, 'utf8'));
      log(`Contract deployed at: ${deploymentData.contractAddress}`, colors.green);
    } else {
      log('Warning: deployment.json file not found after deployment', colors.yellow);
    }
  } catch (error) {
    log(`Error deploying contract: ${error.message}`, colors.red);
    throw error;
  }
}

// Start the Flutter web app
async function startFlutterWebApp() {
  log('Starting Flutter web app...', colors.bright + colors.blue);
  try {
    await executeCommand('flutter', ['run', '-d', 'web-server', '--web-port=3001']);
  } catch (error) {
    log(`Error starting Flutter web app: ${error.message}`, colors.red);
    throw error;
  }
}

// Main function to run everything
async function main() {
  try {
    log('Starting DADI local development environment...', colors.bright + colors.magenta);
    
    // Start Hardhat node
    const hardhatNode = await startHardhatNode();
    
    // Give the node a moment to initialize fully
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Deploy the contract
    await deployContract();
    
    // Start the Flutter web app
    await startFlutterWebApp();
    
    // Handle cleanup when the process exits
    process.on('SIGINT', () => {
      log('Shutting down...', colors.bright + colors.yellow);
      if (hardhatNode) {
        process.kill(-hardhatNode.pid);
      }
      process.exit(0);
    });
    
  } catch (error) {
    log(`Error: ${error.message}`, colors.bright + colors.red);
    process.exit(1);
  }
}

// Run the main function
main();
