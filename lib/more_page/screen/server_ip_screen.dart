import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ServerIPScreen extends StatelessWidget {
  const ServerIPScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.openBox('serverData');
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text(
      //     'Connected Devices',
      //     style: TextStyle(
      //       fontSize: 20,
      //       fontWeight: FontWeight.bold,
      //     ),
      //   ),
      //   backgroundColor: Colors.blue,
      //   foregroundColor: Colors.white,
      //   elevation: 0,
      //   iconTheme: const IconThemeData(color: Colors.white),
      // ),
      body: Column(
        children: [
          Text(
          'Connected Devices',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: Hive.box('serverData').listenable(keys: ['allConnectedDevices']),
              builder: (context, Box box, _) {
                final List<dynamic> allDevices = box.get('allConnectedDevices', defaultValue: <dynamic>[]);
            
                // Separate server and clients
                Map<String, dynamic>? serverDevice;
                List<Map<String, dynamic>> clientDevices = [];
            
                for (var device in allDevices) {
                  final map = Map<String, dynamic>.from(device as Map);
            
                  if (map['deviceType'] == 'server') {
                    serverDevice = map;
                  } else {
                    clientDevices.add(map);
                  }
                }
            
                if (allDevices.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.devices, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No devices connected yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                        Text('Waiting for clients to send data...', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }
                final String serverIp = serverDevice?['clientIp'] ?? 'Unknown IP';
                final int serverbatteryLevel = serverDevice?['batteryLevel'] ?? 0;
                final String serverstate = serverDevice?['batteryState'] ?? 'unknown';
                final double serverscore = serverDevice?['score']?.toDouble() ?? 0.0;
            
                return ListView(
                  children: [
                    // ────────────────── SERVER SECTION (if exists) ──────────────────
                    if (serverDevice != null) ...[
                      Card(
                        color: Colors.white,
                        elevation: 0,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          // leading: Icon(Icons.dns, size: 40, color: Colors.blue),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Server",
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(
                                height: 10,
                              ),
                              Row(
                                children: [
                                   
                                  Icon(Icons.dns, size: 25, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text(
                                    serverIp,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              // Text(
                              //   '$servermanufacturer $servermodel'.trim(),
                              // ),
                              // const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.battery_std,
                                    size: 18,
                                    color: serverbatteryLevel > 20 ? Colors.green : Colors.red,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '$serverbatteryLevel% ($serverstate)',
                                      style: const TextStyle(fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Score',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                serverscore.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _showDeviceDetails(context, serverDevice!),
                        ),
                      ),
                      const Divider(height: 1, color: Colors.grey),
                    ],
            
                    // ────────────────── CONNECTED DEVICES HEADING ──────────────────
                    if (clientDevices.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Text(
                          'Connected Clients (${clientDevices.length})',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                        ),
                      ),
            
                    // ────────────────── CLIENT DEVICES LIST ──────────────────
                    if (clientDevices.isEmpty && serverDevice != null)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'No client devices connected yet',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: clientDevices.length,
                        itemBuilder: (context, index) {
                          final device = clientDevices[index];
            
                          final String clientIp = device['clientIp'] ?? 'Unknown IP';
                          final int batteryLevel = device['batteryLevel'] ?? 0;
                          final String state = device['batteryState'] ?? 'unknown';
                          final int priority = device['priority'] ?? 0;
                          final double score = device['score']?.toDouble() ?? 0.0;
            
                          final Color rowColor = index.isEven ? Colors.grey.shade100 : Colors.white;
            
                          return Card(
                            color: rowColor,
                            elevation: 0,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              title: Row(
                                children: [
                                  // Only show priority badge if in top 5
                                  if (priority > 0)
                                    Container(
                                      width: 36,
                                      height: 36,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: priority <= 3 ? Colors.blue : Colors.grey,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        priority.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 36,
                                      height: 36,
                                      alignment: Alignment.center,
                                      child: Icon(Icons.circle, size: 12, color: Colors.grey[400]),
                                    ),
            
                                  const SizedBox(width: 12),
                                  Text(
                                    clientIp,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  // Text('$manufacturer $model'.trim()),
                                  // const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.battery_std,
                                        size: 18,
                                        color: batteryLevel > 20 ? Colors.green : Colors.red,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '$batteryLevel% ($state)',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Score',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  Text(
                                    score.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () => _showDeviceDetails(context, device),
                            ),
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDeviceDetails(BuildContext context, Map<String, dynamic> device) {
    final String deviceType = device['deviceType'] ?? 'client';
    final String clientIp = device['clientIp'] ?? 'Unknown IP';
    final String model = device['model'] ?? 'Unknown';
    final String manufacturer = device['manufacturer'] ?? '';
    final int batteryLevel = int.tryParse(device['batteryLevel']?.toString() ?? '0') ?? 0;
    final String batteryState = device['batteryState'] ?? 'unknown';
    final int priority = int.tryParse(device['priority']?.toString() ?? '0') ?? 0;
    final String osVersion = device['osVersion'] ?? 'Unknown OS';

    final double score = _toDouble(device['score']);
    final double totalRamGB = _toDouble(device['totalRamGB']);
    final double freeRamGB = _toDouble(device['freeRamGB']);
    final double totalStorageGB = _toDouble(device['totalStorageGB']);
    final double freeStorageGB = _toDouble(device['freeStorageGB']);

    final int dailyAppUsageMinutes = int.tryParse(device['dailyAppUsageMinutes']?.toString() ?? '0') ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            if (deviceType == 'server') ...[
              const Icon(Icons.wifi, color: Colors.blue),
              const SizedBox(width: 8),
            ],
            Text(
              deviceType == 'server' ? 'Server Details' : 'Device Details',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (deviceType != 'server')
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  priority.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('IP Address', clientIp),
              _detailRow('Manufacturer', manufacturer.trim()),
              _detailRow('Model', model.trim()),
              _detailRow('OS Version', osVersion),
              _detailRow('RAM', '${totalRamGB.toStringAsFixed(1)} GB'),
              _detailRow('Free RAM', '${freeRamGB.toStringAsFixed(1)} GB'),
              _detailRow('Storage', '${totalStorageGB.toStringAsFixed(1)} GB'),
              _detailRow('Free Storage', '${freeStorageGB.toStringAsFixed(1)} GB'),
              _detailRow('Battery', '$batteryLevel% ($batteryState)'),
              _detailRow('Daily Usage', '$dailyAppUsageMinutes minutes'),
              _detailRow('Performance Score', score.toStringAsFixed(1)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CLOSE',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              ':',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
