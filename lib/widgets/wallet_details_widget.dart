import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/wallet_service_interface.dart';
import 'wallet_transaction_list.dart';
import 'wallet_send_dialog.dart';
import 'wavy_background.dart'; // Import wavy background

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
      final success = await walletService.unlockWallet(password: _passwordController.text);
      
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
    // Check if wallet is locked before showing backup options
    if (!_isUnlocked) {
      // If wallet is locked, show unlock dialog first
      final success = await _promptUnlockWallet();
      if (!success) {
        // If unlock failed or was canceled, don't proceed
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wallet must be unlocked to view backup options'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    
    // Now that we've confirmed the wallet is unlocked, show backup options
    await showModalBottomSheet(
      context: context,
      builder: (context) => _buildBackupOptions(),
    );
  }

  Future<bool> _promptUnlockWallet() async {
    final passwordController = TextEditingController();
    bool obscurePassword = true;
    bool isLoading = false;
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Unlock Wallet'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Your wallet is locked. Please enter your password to unlock it.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.password),
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
                enableSuggestions: false,
                autocorrect: false,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setState(() {
                        isLoading = true;
                      });
                      
                      try {
                        final walletService = Provider.of<WalletServiceInterface>(context, listen: false);
                        final success = await walletService.unlockWallet(password: passwordController.text);
                        
                        if (success) {
                          // Update the state to reflect that the wallet is now unlocked
                          if (mounted) {
                            setState(() {
                              _isUnlocked = true;
                            });
                          }
                          Navigator.pop(context, true);
                        } else {
                          if (mounted) {
                            setState(() {
                              isLoading = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Invalid password'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() {
                            isLoading = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error unlocking wallet: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('UNLOCK'),
            ),
          ],
        ),
      ),
    );
    
    return result ?? false;
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
    // Check if wallet is already unlocked
    if (!_isUnlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wallet must be unlocked to view recovery phrase'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Show loading indicator
    setState(() {
      _isLoading = true;
    });
    
    final walletService = Provider.of<WalletServiceInterface>(context, listen: false);
    
    try {
      final mnemonic = await walletService.getMnemonic();
      
      // Hide loading indicator
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      
      if (!mounted) return;
      
      if (mnemonic == null || mnemonic.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to retrieve recovery phrase'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Show the mnemonic in a dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Recovery Phrase'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Write these words down on paper and keep them in a secure location. Anyone with these words can access your funds.',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  mnemonic,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Copy to Clipboard'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: mnemonic));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Recovery phrase copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
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
    } catch (e) {
      // Hide loading indicator
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error retrieving recovery phrase: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showPrivateKeyDialog() async {
    // Check if wallet is already unlocked
    if (!_isUnlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wallet must be unlocked to view private key'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final walletService = Provider.of<WalletServiceInterface>(context, listen: false);
    
    try {
      final privateKey = await walletService.getPrivateKey();
      
      if (privateKey == null || privateKey.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to retrieve private key'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Show the private key in a dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Private Key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'WARNING: Never share your private key with anyone. Anyone with your private key has full control over your wallet.',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  privateKey,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                ),
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error retrieving private key: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

    return WavyBackground(
      primaryColor: Theme.of(context).colorScheme.primary,
      secondaryColor: Theme.of(context).colorScheme.secondary,
      child: _buildWalletContent(address!),
    );
  }

  Widget _buildWalletContent(String address) {
    return RefreshIndicator(
      onRefresh: _refreshWalletData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildWalletHeader(address),
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
    final theme = Theme.of(context);
    
    return WavyBackground(
      primaryColor: theme.colorScheme.primary,
      secondaryColor: theme.colorScheme.secondary,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.lock,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Wallet is Locked',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Enter your password to unlock your wallet and access your funds.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.password),
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
                filled: true,
                fillColor: theme.colorScheme.surface.withOpacity(0.8),
              ),
              obscureText: _obscurePassword,
              enableSuggestions: false,
              autocorrect: false,
              onSubmitted: (_) => _unlockWallet(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _unlockWallet,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text(
                      'UNLOCK WALLET',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _isLoading ? null : _confirmResetWallet,
              child: Text(
                'Reset Wallet',
                style: TextStyle(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletHeader(String address) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet,
                  size: 24,
                  color: Colors.amber,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Wallet Address',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: address));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Address copied to clipboard'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  tooltip: 'Copy address',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${address.substring(0, 10)}...${address.substring(address.length - 8)}',
              style: const TextStyle(
                fontSize: 16,
                fontFamily: 'monospace',
              ),
            ),
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Full Wallet Address'),
                    content: SelectableText(
                      address,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('CLOSE'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('View full address'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(50, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                alignment: Alignment.centerLeft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Theme.of(context).colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Balance',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _balance.toStringAsFixed(4),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'ETH',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _refreshWalletData,
                  tooltip: 'Refresh balance',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          icon: Icons.send,
          label: 'Send',
          onTap: _showSendDialog,
          color: Colors.blue,
        ),
        _buildActionButton(
          icon: Icons.backup,
          label: 'Backup',
          onTap: _showBackupOptions,
          color: Colors.green,
        ),
        _buildActionButton(
          icon: Icons.lock,
          label: 'Lock',
          onTap: _lockWallet,
          color: Colors.orange,
        ),
        _buildActionButton(
          icon: Icons.delete_forever,
          label: 'Reset',
          onTap: _confirmResetWallet,
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: MediaQuery.of(context).size.width / 2 - 24,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
