import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/web3_service.dart';
import 'services/mock_buttplug_service.dart';
import 'screens/home_screen.dart';
import 'dart:developer' as developer;

void main() {
  // Initialize logging
  developer.log('Starting DADI application...', name: 'Main');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Web3Service()),
        ChangeNotifierProvider(create: (_) => MockButtplugService()),
      ],
      child: MaterialApp(
        title: 'DADI',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
