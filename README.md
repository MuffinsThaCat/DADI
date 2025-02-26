# DADI - Decentralized Auction for Device Interaction

A Flutter web application that enables decentralized auctions for device control using Ethereum smart contracts.

## Prerequisites

- [Flutter](https://flutter.dev/docs/get-started/install) (latest stable version)
- [Node.js](https://nodejs.org/) (v16 or later)
- [MetaMask](https://metamask.io/) browser extension
- [Git](https://git-scm.com/)

## Setup

1. Clone the repository:
```bash
git clone https://github.com/MuffinsThaCat/DADI.git
cd DADI
```

2. Install Node.js dependencies:
```bash
npm install
```

3. Install Flutter dependencies:
```bash
flutter pub get
```

4. Start a local Hardhat node:
```bash
npx hardhat node
```

5. In a new terminal, deploy the smart contract:
```bash
npx hardhat run --network localhost scripts/deploy.js
```

6. Configure MetaMask:
   - Add a new network with:
     - Network Name: Hardhat Local
     - RPC URL: http://127.0.0.1:8545
     - Chain ID: 31337
   - Import a test account using the private key from the Hardhat node output

## Running the App

1. Start the Flutter web app:
```bash
flutter run -d web-server --web-port=3001
```

2. Open your browser and navigate to:
```
http://localhost:3001
```

3. Connect MetaMask when prompted by the app

## Features

- Create auctions for device control
- Place bids on active auctions
- View auction history and status
- Control devices during won time slots
- Real-time updates using blockchain events

## Development

- Smart Contract: `contracts/DADIAuction.sol`
- Flutter App: `lib/` directory
  - Screens: `lib/screens/`
  - Services: `lib/services/`
  - Contract Bindings: `lib/contracts/`

## Testing

Run smart contract tests:
```bash
npx hardhat test
```

Run Flutter tests:
```bash
flutter test