import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dadi/services/web3_service.dart';
import 'package:dadi/utils/auction_simulator.dart';

class AuctionSimulatorScreen extends StatefulWidget {
  const AuctionSimulatorScreen({super.key});

  @override
  State<AuctionSimulatorScreen> createState() => _AuctionSimulatorScreenState();
}

class _AuctionSimulatorScreenState extends State<AuctionSimulatorScreen> {
  final _deviceIdController = TextEditingController();
  final _durationController = TextEditingController(text: '2');
  final _startingBidController = TextEditingController(text: '0.1');
  final _numberOfBidsController = TextEditingController(text: '5');
  
  bool _isSimulating = false;
  String _simulationStatus = '';
  Map<String, dynamic>? _simulationResults;
  
  late AuctionSimulator _auctionSimulator;
  
  @override
  void initState() {
    super.initState();
    // Initialize with a random device ID
    _deviceIdController.text = 'sim-device-${DateTime.now().millisecondsSinceEpoch}';
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final web3Service = Provider.of<Web3Service>(context);
    _auctionSimulator = AuctionSimulator(web3Service);
  }
  
  @override
  void dispose() {
    _deviceIdController.dispose();
    _durationController.dispose();
    _startingBidController.dispose();
    _numberOfBidsController.dispose();
    super.dispose();
  }
  
  Future<void> _simulateAuction() async {
    if (!_auctionSimulator.isSimulationAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Simulation is only available in mock mode')),
      );
      return;
    }
    
    setState(() {
      _isSimulating = true;
      _simulationStatus = 'Starting simulation...';
      _simulationResults = null;
    });
    
    try {
      final deviceId = _deviceIdController.text;
      final duration = Duration(hours: int.parse(_durationController.text));
      final startingBid = double.parse(_startingBidController.text);
      final numberOfBids = int.parse(_numberOfBidsController.text);
      
      setState(() {
        _simulationStatus = 'Creating auction...';
      });
      
      final results = await _auctionSimulator.simulateCompleteAuction(
        deviceId: deviceId,
        auctionDuration: duration,
        startingBid: startingBid,
        numberOfBids: numberOfBids,
      );
      
      setState(() {
        _simulationResults = results;
        _simulationStatus = 'Simulation completed successfully!';
      });
    } catch (e) {
      setState(() {
        _simulationStatus = 'Simulation failed: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isSimulating = false;
      });
    }
  }
  
  Future<void> _simulateMultipleAuctions() async {
    if (!_auctionSimulator.isSimulationAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Simulation is only available in mock mode')),
      );
      return;
    }
    
    setState(() {
      _isSimulating = true;
      _simulationStatus = 'Starting multiple auction simulations...';
      _simulationResults = null;
    });
    
    try {
      const count = 3; // Simulate 3 auctions
      
      setState(() {
        _simulationStatus = 'Creating $count auctions...';
      });
      
      final results = await _auctionSimulator.simulateMultipleAuctions(count);
      
      setState(() {
        _simulationResults = {
          'multipleAuctions': results,
          'count': results.length,
        };
        _simulationStatus = 'Successfully simulated ${results.length} auctions!';
      });
    } catch (e) {
      setState(() {
        _simulationStatus = 'Simulation failed: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isSimulating = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final web3Service = Provider.of<Web3Service>(context);
    final isMockMode = web3Service.isMockMode;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auction Simulator'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mock mode status
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: isMockMode ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                children: [
                  Icon(
                    isMockMode ? Icons.check_circle : Icons.error,
                    color: isMockMode ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      isMockMode
                          ? 'Mock mode is enabled. Simulation available.'
                          : 'Mock mode is disabled. Simulation not available.',
                      style: TextStyle(
                        color: isMockMode ? Colors.green.shade900 : Colors.red.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16.0),
            
            // Simulation form
            if (isMockMode) ...[
              const Text(
                'Auction Simulation Parameters',
                style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16.0),
              
              // Device ID
              TextField(
                controller: _deviceIdController,
                decoration: const InputDecoration(
                  labelText: 'Device ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8.0),
              
              // Duration
              TextField(
                controller: _durationController,
                decoration: const InputDecoration(
                  labelText: 'Auction Duration (hours)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8.0),
              
              // Starting Bid
              TextField(
                controller: _startingBidController,
                decoration: const InputDecoration(
                  labelText: 'Starting Bid (ETH)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8.0),
              
              // Number of Bids
              TextField(
                controller: _numberOfBidsController,
                decoration: const InputDecoration(
                  labelText: 'Number of Bids',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16.0),
              
              // Simulation buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSimulating ? null : _simulateAuction,
                      child: const Text('Simulate Single Auction'),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSimulating ? null : _simulateMultipleAuctions,
                      child: const Text('Simulate Multiple Auctions'),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16.0),
              
              // Simulation status
              if (_simulationStatus.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Row(
                    children: [
                      _isSimulating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.0),
                            )
                          : const Icon(Icons.info, color: Colors.blue),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Text(_simulationStatus),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 16.0),
              
              // Simulation results
              if (_simulationResults != null) ...[
                const Text(
                  'Simulation Results',
                  style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8.0),
                
                if (_simulationResults!.containsKey('multipleAuctions')) ...[
                  // Multiple auctions results
                  Text(
                    'Successfully simulated ${_simulationResults!['count']} auctions',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8.0),
                  
                  // List of auctions
                  ..._buildMultipleAuctionResults(),
                ] else ...[
                  // Single auction results
                  _buildSingleAuctionResults(),
                ],
              ],
            ] else ...[
              // Mock mode disabled message
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text(
                    'Enable mock mode to use the auction simulator',
                    style: TextStyle(fontSize: 16.0),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildSingleAuctionResults() {
    final results = _simulationResults!;
    final startTime = results['startTime'] as DateTime;
    final endTime = results['endTime'] as DateTime;
    final bidHistory = results['bidHistory'] as List<dynamic>;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Device ID: ${results['deviceId']}'),
            Text('Start Time: ${startTime.toString()}'),
            Text('End Time: ${endTime.toString()}'),
            Text('Starting Bid: ${results['startingBid']} ETH'),
            Text('Final Bid: ${results['finalBid']} ETH'),
            Text('Number of Bids: ${results['numberOfBids']}'),
            Text('Winner: ${results['winner']}'),
            Text('Finalized: ${results['finalized']}'),
            
            const SizedBox(height: 8.0),
            const Text('Bid History:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4.0),
            
            ...bidHistory.asMap().entries.map((entry) {
              final index = entry.key;
              final bid = entry.value as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  'Bid #${index + 1}: ${bid['amount']} ETH by ${bid['bidder']}',
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
  
  List<Widget> _buildMultipleAuctionResults() {
    final auctions = _simulationResults!['multipleAuctions'] as List<dynamic>;
    
    return auctions.map((auction) {
      final Map<String, dynamic> auctionData = auction as Map<String, dynamic>;
      final startTime = auctionData['startTime'] as DateTime;
      final endTime = auctionData['endTime'] as DateTime;
      
      return Card(
        margin: const EdgeInsets.only(bottom: 8.0),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Device ID: ${auctionData['deviceId']}'),
              Text('Duration: ${endTime.difference(startTime).inHours} hours'),
              Text('Final Bid: ${auctionData['finalBid']} ETH'),
              Text('Bids: ${auctionData['numberOfBids']}'),
              Text('Winner: ${auctionData['winner']}'),
            ],
          ),
        ),
      );
    }).toList();
  }
}
