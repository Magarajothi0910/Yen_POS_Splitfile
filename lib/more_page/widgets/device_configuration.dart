import 'package:flutter/material.dart';
import 'package:yen_pos/more_page/screen/server_ip_screen.dart';
import 'package:yen_pos/more_page/screen/wifi_ip_list.dart';

class DeviceConfigurationScreen extends StatelessWidget {
  const DeviceConfigurationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // return const WifiDevicesScreen();
    return const ServerIPScreen();
  }
}
