import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/wallet_service_interface.dart';
import 'wallet_transaction_list.dart';
import 'wallet_send_dialog.dart';

/// Widget for displaying wallet details and functionality
class WalletDetailsWidget extends StatefulWidget {
  const WalletDetailsWidget({Key? key}) : super(key: key);

  @override
  State<WalletDetailsWidget> createState() => _WalletDetailsWidgetState();
}

class _WalletDetailsWidgetState extends State<WalletDetailsWidget> {
  bool _isLoading = false;
  bool _isUnlocked = false;
  double _balance = 0.0;
  List<Map<String, dynamic>> _transactions = [];
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _checkWalletStatus();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkWalletStatus() async {
    final walletService = Provider.of<WalletServiceInterface>(context, listen: false);
    
    setState(() {
      _isLoading = true;
      _isUnlocked = walletService.isUnlocked;
    });

    if (_isUnlocked) {
      await _refreshWalletData();
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _refreshWalletData() async {
    final walletService = Provider.of<WalletServiceInterface>(context, listen: false);
    
    try {
      final balance = await walletService.balance;
      final transactions = await walletService.getTransactionHistory();
      
      if (!mounted) return;
      
      setState(() {
        _balance = balance;
        _transactions = transactions;
      });
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error refreshing wallet data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _unlockWallet() async {
    if (_passwordController.text.isEmpty) {
      return;
    }
    
    try {
      final walletService = Provider.of<WalletServiceInterface>(context, listen: false);
      final success = await walletService.unlockWallet(
        password: _passwordController.text,
      );
      
      if (!mounted) return;
      
      if (success) {
        setState(() {
          _isUnlocked = true;
        });
        await _refreshWalletData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid password'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error unlocking wallet: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _lockWallet() async {
    try {
      final walletService = Provider.of<WalletServiceInterface>(context, listen: false);
      await walletService.lockWallet();
      
      if (!mounted) return;
      
      setState(() {
        _isUnlocked = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error locking wallet: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showSendDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const WalletSendDialog(),
    );

    if (result == true) {
      await _refreshWalletData();
    }
  }

  Future<void> _showBackupOptions() async {
    await showModalBottomSheet(
      context: context,
      builder: (context) => _buildBackupOptions(),
    );
  }

  Widget _buildBackupOptions() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Backup Options',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.vpn_key),
              title: const Text('View Recovery Phrase'),
              subtitle: const Text('12-word backup phrase'),
              onTap: () {
                Navigator.pop(context);
                _showRecoveryPhraseDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.key),
              title: const Text('Export Private Key'),
              subtitle: const Text('View your private key'),
              onTap: () {
                Navigator.pop(context);
                _showPrivateKeyDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRecoveryPhraseDialog() async {
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Enter Password'),
          content: TextField(
            controller: passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    obscurePassword = !obscurePassword;
                  });
                },
              ),
            ),
            obscureText: obscurePassword,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final walletService = Provider.of<WalletServiceInterface>(context, listen: false);
                  final mnemonic = await walletService.exportMnemonic(
                    password: passwordController.text,
                  );
                  
                  if (!mounted) return;
                  
                  Navigator.pop(context, mnemonic);
                } catch (e) {
                  if (!mounted) return;
                  
                  Navigator.pop(context);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('CONFIRM'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      _showMnemonicDisplay(result);
    }
  }

  void _showMnemonicDisplay(String mnemonic) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recovery Phrase'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Write down these words in order and keep them in a safe place. Anyone with this phrase can access your wallet.',
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                mnemonic,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: mnemonic));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Recovery phrase copied to clipboard'),
                  ),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('COPY TO CLIPBOARD'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPrivateKeyDialog() async {
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Enter Password'),
          content: TextField(
            controller: passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    obscurePassword = !obscurePassword;
                  });
                },
              ),
            ),
            obscureText: obscurePassword,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final walletService = Provider.of<WalletServiceInterface>(context, listen: false);
                  final privateKey = await walletService.exportPrivateKey(
                    password: passwordController.text,
                  );
                  if (!mounted) return;
                  Navigator.pop(context, privateKey);
                } catch (e) {
                  if (!mounted) return;
                  Navigator.pop(context);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('CONFIRM'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      _showPrivateKeyDisplay(result);
    }
  }

  void _showPrivateKeyDisplay(String privateKey) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Private Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'WARNING: Never share your private key with anyone. Anyone with this key has full access to your wallet.',
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                privateKey,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: privateKey));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Private key copied to clipboard'),
                  ),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('COPY TO CLIPBOARD'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetWallet() async {
    final walletService = Provider.of<WalletServiceInterface>(context, listen: false);
    await walletService.resetWallet();
    return;
  }

  Future<void> _confirmResetWallet() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Wallet'),
        content: const Text('Are you sure you want to reset your wallet? This will delete all wallet data and cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Perform the async operation in a separate method
        await _resetWallet();
        
        // Check if still mounted before using context
        if (!mounted) return;
        
        // Force a rebuild of the parent widget
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        );
      } catch (e) {
        // Check if still mounted before using context
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting wallet: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletService = Provider.of<WalletServiceInterface>(context);
    final address = walletService.currentAddress;

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (!_isUnlocked) {
      return _buildUnlockScreen();
    }

    return RefreshIndicator(
      onRefresh: _refreshWalletData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildWalletHeader(address!),
              const SizedBox(height: 24),
              _buildBalanceCard(),
              const SizedBox(height: 16),
              _buildActionButtons(),
              const SizedBox(height: 24),
              const Text(
                'Transaction History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              WalletTransactionList(transactions: _transactions),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnlockScreen() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.lock,
            size: 80,
            color: Colors.blue,
          ),
          const SizedBox(height: 24),
          const Text(
            'Unlock Your Wallet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Enter your password to access your wallet',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            obscureText: _obscurePassword,
            onSubmitted: (_) => _unlockWallet(),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _unlockWallet,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16),
            ),
            child: const Text('UNLOCK'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _confirmResetWallet,
            child: const Text('Reset Wallet'),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletHeader(String address) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Wallet Address',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatAddress(address),
              style: const TextStyle(
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: address));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Address copied to clipboard'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy Address',
                ),
                IconButton(
                  onPressed: _lockWallet,
                  icon: const Icon(Icons.lock),
                  tooltip: 'Lock Wallet',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Card(
      elevation: 2,
      color: Colors.blue,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Balance',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_balance.toStringAsFixed(6)} ETH',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _showSendDialog,
            icon: const Icon(Icons.send),
            label: const Text('SEND'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _showBackupOptions,
            icon: const Icon(Icons.backup),
            label: const Text('BACKUP'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  String _formatAddress(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }
}
