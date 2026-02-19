import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityHandler {
  static final ConnectivityHandler _instance = ConnectivityHandler._internal();
  factory ConnectivityHandler() => _instance;
  ConnectivityHandler._internal();

  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  Future<void> initialize() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = result != ConnectivityResult.none;

    _connectivity.onConnectivityChanged.listen((result) {
      _isOnline = result != ConnectivityResult.none;
      debugPrint('🌐 Internet: ${_isOnline ? "Connected" : "Disconnected"}');
    });
  }

  Future<bool> checkConnection(BuildContext context) async {
    if (!_isOnline) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 12),
                Text('No internet connection'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return false;
    }
    return true;
  }
}