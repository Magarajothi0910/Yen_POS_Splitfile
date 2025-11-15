import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class ConnectivityProviderDine with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isConnected = true;

  bool get isConnected => _isConnected;

  ConnectivityProviderDine() {
    _checkInitialConnection();
    _subscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> _checkInitialConnection() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      _updateConnectionStatus(connectivityResult);
    } catch (e) {
      debugPrint('Error checking initial connection: $e');
      _isConnected = false;
      notifyListeners();
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final wasConnected = _isConnected;
    _isConnected = results.any((result) => result == ConnectivityResult.wifi || result == ConnectivityResult.mobile);
    if (wasConnected != _isConnected) {
      notifyListeners();
    }
  }

  Future<void> checkConnection() async {
    await _checkInitialConnection();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
