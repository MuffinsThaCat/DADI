import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/wallet_service_interface.dart';

/// Widget for importing an existing wallet
class WalletImportWidget extends StatefulWidget {
  /// Callback when wallet is imported
  final VoidCallback onWalletImported;

  const WalletImportWidget({
    Key? key,
    required this.onWalletImported,
  }) : super(key: key);

  @override
  State<WalletImportWidget> createState() => _WalletImportWidgetState();
}

class _WalletImportWidgetState extends State<WalletImportWidget> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _importDataController = TextEditingController();
  bool _isImporting = false;
  bool _obscurePassword = true;
  
  ImportMethod _importMethod = ImportMethod.mnemonic;

  @override
  void dispose() {
    _passwordController.dispose();
    _importDataController.dispose();
    super.dispose();
  }

  Future<void> _importWallet() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isImporting = true;
    });

    try {
      final walletService = Provider.of<WalletServiceInterface>(context, listen: false);
      String address;
      
      if (_importMethod == ImportMethod.mnemonic) {
        address = await walletService.importFromMnemonic(
          mnemonic: _importDataController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        address = await walletService.importFromPrivateKey(
          privateKey: _importDataController.text.trim(),
          password: _passwordController.text,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Wallet imported successfully: ${_formatAddress(address)}'),
          backgroundColor: Colors.green,
        ),
      );

      widget.onWalletImported();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to import wallet: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  String _formatAddress(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.file_download,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            const Text(
              'Import Existing Wallet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Import your wallet using a recovery phrase or private key.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Import method selection
            SegmentedButton<ImportMethod>(
              segments: const [
                ButtonSegment<ImportMethod>(
                  value: ImportMethod.mnemonic,
                  label: Text('Recovery Phrase'),
                  icon: Icon(Icons.vpn_key),
                ),
                ButtonSegment<ImportMethod>(
                  value: ImportMethod.privateKey,
                  label: Text('Private Key'),
                  icon: Icon(Icons.key),
                ),
              ],
              selected: {_importMethod},
              onSelectionChanged: (Set<ImportMethod> selection) {
                setState(() {
                  _importMethod = selection.first;
                  _importDataController.clear();
                });
              },
            ),
            
            const SizedBox(height: 24),
            
            TextFormField(
              controller: _importDataController,
              decoration: InputDecoration(
                labelText: _importMethod == ImportMethod.mnemonic
                    ? 'Recovery Phrase'
                    : 'Private Key',
                border: const OutlineInputBorder(),
                hintText: _importMethod == ImportMethod.mnemonic
                    ? 'Enter 12 or 24 word recovery phrase'
                    : 'Enter private key',
              ),
              maxLines: _importMethod == ImportMethod.mnemonic ? 3 : 1,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return _importMethod == ImportMethod.mnemonic
                      ? 'Please enter your recovery phrase'
                      : 'Please enter your private key';
                }
                
                if (_importMethod == ImportMethod.mnemonic) {
                  final wordCount = value.trim().split(' ').length;
                  if (wordCount != 12 && wordCount != 24) {
                    return 'Recovery phrase must be 12 or 24 words';
                  }
                }
                
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: const OutlineInputBorder(),
                helperText: 'Create a new password to secure your wallet',
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
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a password';
                }
                if (value.length < 8) {
                  return 'Password must be at least 8 characters';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 32),
            
            ElevatedButton(
              onPressed: _isImporting ? null : _importWallet,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
              ),
              child: _isImporting
                  ? const CircularProgressIndicator()
                  : const Text('IMPORT WALLET'),
            ),
            
            const SizedBox(height: 16),
            
            const Text(
              'Warning: Never share your recovery phrase or private key with anyone. Anyone with this information will have full access to your wallet.',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Import method enum
enum ImportMethod {
  mnemonic,
  privateKey,
}
