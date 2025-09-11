import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class ConnectivityProvider with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _subscription;
  bool _isConnected = true;

  bool get isConnected => _isConnected;

  ConnectivityProvider() {
    _subscription = _connectivity.onConnectivityChanged.listen(
            _updateConnectionStatus as void Function(
                List<ConnectivityResult> event)?)
        as StreamSubscription<ConnectivityResult>?;
    _checkInitialConnection();
  }

  Future<void> _checkInitialConnection() async {
    var connectivityResult = await _connectivity.checkConnectivity();
    _updateConnectionStatus(connectivityResult as ConnectivityResult);
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    bool previousStatus = _isConnected;
    _isConnected = result != ConnectivityResult.none;
    if (previousStatus != _isConnected) {
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
