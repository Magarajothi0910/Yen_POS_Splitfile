import 'package:dio/dio.dart' hide Response;
import 'package:dio/src/response.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get_connect/http/src/response/response.dart' hide Response;
import 'package:get/get_connect/http/src/utils/utils.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Sale_order/Widgets/Send_data_to_server.dart';
import 'package:yen_pos/Server_Client/sendDataToClients.dart';
import 'package:yen_pos/kotpreinvoice/models/appType.dart';
import 'package:yen_pos/kotpreinvoice/utils/responsive.dart';
import 'package:yen_pos/printer_screen/printer_config.dart';

class ServerIPScreen extends StatelessWidget {
  const ServerIPScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.getPadding(context);
    final scale = Responsive.getScaleFactor(context);

    bool isValidIp(String ip) {
      final regex = RegExp(
        r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}'
        r'(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
      );
      return regex.hasMatch(ip);
    }

    final Dio dio = Dio(
      BaseOptions(
        // baseUrl: "https://yenerp.com/fluttertestapi/",
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    Future<Response?> patchSubnetIp(String ip, String branchAlias) async {
      debugPrint('postSubnetIp e1');
      try {
        debugPrint('postSubnetIp e2');

        final response = await dio.patch(
          "https://yenerp.com/fluttertestapi/ipConfig/patch_ip?branchAlias=$branchAlias&ip=$ip",
        );
        debugPrint('postSubnetIp e3');

        return response;
      } catch (e) {
        debugPrint('postSubnetIp $e');
        return null;
      }
    }

    void _showEditIpDialog(BuildContext context) {
      final TextEditingController ipController = TextEditingController(
        text: locSubnetIp.value,
      );

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔵 Title
                    Row(
                      children: const [
                        Icon(Icons.wifi, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Edit Subnet IP',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 🧾 Input Field
                    TextField(
                      controller: ipController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        IpInputFormatter(),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Subnet IP',
                        hintText: '192.168.1.10',
                        prefixIcon: const Icon(
                          Icons.router,
                          color: Colors.blue,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Colors.blue,
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 🔘 Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                              side: const BorderSide(color: Colors.blue),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final ip = ipController.text.trim();

                              if (isValidIp(ip)) {
                                locSubnetIp.value = ip;
                                patchSubnetIp(ip, locationId);
                                Navigator.pop(context);
                                sendDataToClients({
                                  'action': 'subnetIpChanged',
                                  'ip': ip,
                                }, clients);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Invalid IP address'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Save',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

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
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20),
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.withOpacity(0.6), Colors.blue],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),

                // color: Colors.blue,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'SubNetIp',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: ValueListenableBuilder<String>(
                      valueListenable: locSubnetIp,
                      builder: (context, value, _) {
                        return Text(
                          value,
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (appTypeNotifier.value == APP_SERVER)
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        size: 20,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        _showEditIpDialog(context);
                      },
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: Hive.box(
                'serverData',
              ).listenable(keys: ['allConnectedDevices']),
              builder: (context, Box box, _) {
                final List<dynamic> allDevices = box.get(
                  'allConnectedDevices',
                  defaultValue: <dynamic>[],
                );
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

                // ✅ FIX: sort clients by priority
                clientDevices.sort((a, b) {
                  final pa = a['priority'] ?? 9999;
                  final pb = b['priority'] ?? 9999;
                  return pa.compareTo(pb);
                });

                if (allDevices.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.devices, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No devices connected yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        Text(
                          'Waiting for clients to send data...',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                final int serverbatteryLevel =
                    serverDevice?['batteryLevel'] ?? 0;
                final String serverstate =
                    serverDevice?['batteryState'] ?? 'unknown';
                final int serverscore = serverDevice?['score'] ?? 0;
                final String serverApp = serverDevice?['app'] ?? 'unknown';
                final String deviceName =
                    serverDevice?['deviceName'] ?? 'No Name';
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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          // leading: Icon(Icons.dns, size: 40, color: Colors.blue),
                          title: Row(
                            children: [
                              Icon(
                                Icons.dns,
                                size: 22 * scale,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  deviceName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: Responsive.getFontSize(
                                      context,
                                      baseSize: 16,
                                    ),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.battery_std,
                                    size: 18,
                                    color: serverbatteryLevel > 20
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '$serverbatteryLevel% ($serverstate)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: Responsive.getFontSize(
                                          context,
                                          baseSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // 🟧 Dispatch badge
                                  Card(
                                    color: Colors.blue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6 * scale,
                                        vertical: 3 * scale,
                                      ),
                                      child: Text(
                                        serverApp,
                                        style: TextStyle(
                                          fontSize: Responsive.getFontSize(
                                            context,
                                            baseSize: 11,
                                          ),
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
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
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                serverscore.toString(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          onTap: () =>
                              _showDeviceDetails(context, serverDevice!, 0),
                        ),
                      ),
                      const Divider(height: 1, color: Colors.grey),
                    ],
                    // ────────────────── CONNECTED DEVICES HEADING ──────────────────
                    if (clientDevices.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Text(
                          'Priority devices (${clientDevices.length})',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
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
                      appTypeNotifier.value == APP_SERVER
                          ? ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: clientDevices.length,

                              onReorder: (oldIndex, newIndex) async {
                                if (newIndex > oldIndex) newIndex--;

                                final movedClient = clientDevices[oldIndex];
                                final String clientIp = movedClient['clientIp'];

                                debugPrint(
                                  '🔁 UI reorder: $clientIp from $oldIndex → $newIndex',
                                );

                                // Update UI immediately (optimistic UI)
                                final item = clientDevices.removeAt(oldIndex);
                                clientDevices.insert(newIndex, item);

                                // 🔑 IMPORTANT:
                                // +1 because server is index 0 in connectedDevices
                                final payload = {
                                  'action': 'reorderClient',
                                  'clientIp': clientIp,
                                  'targetOrderIndex':
                                      newIndex + 1, // desired position
                                };

                                debugPrint(
                                  '📡 Sending reorder payload to server: $payload',
                                );

                                await sendataToServer(payload);
                              },
                              itemBuilder: (context, index) {
                                final device = clientDevices[index];
                                final String clientIp =
                                    device['clientIp'] ?? 'Unknown IP';
                                final int batteryLevel =
                                    device['batteryLevel'] ?? 0;
                                final String state =
                                    device['batteryState'] ?? 'unknown';
                                final int priority = index + 1;
                                final String app = device['app'] ?? 'Unkn';
                                final String deviceName =
                                    device['deviceName'] ?? 'No name';
                                final int score = device['score'] ?? 0;
                                return Card(
                                  key: ValueKey(
                                    clientIp,
                                  ), // ✅ REQUIRED for reorder
                                  color: index.isEven
                                      ? Colors.grey.shade100
                                      : Colors.white,
                                  elevation: 0,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.zero,
                                  ),
                                  child: ListTile(
                                    title: Row(
                                      children: [
                                        // 🔵 Priority circle
                                        ReorderableDragStartListener(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              right: 10,
                                            ),
                                            child: Icon(
                                              Icons.drag_handle,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          index: index,
                                        ),
                                        Container(
                                          width: 32 * scale,
                                          height: 32 * scale,
                                          alignment: Alignment.center,
                                          decoration: const BoxDecoration(
                                            color: Colors.blue,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            priority.toString(),
                                            style: TextStyle(
                                              fontSize: Responsive.getFontSize(
                                                context,
                                                baseSize: 14,
                                              ),
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // 🖥️ Client IP
                                        Expanded(
                                          child: Text(
                                            deviceName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: Responsive.getFontSize(
                                                context,
                                                baseSize: 16,
                                              ),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Row(
                                      children: [
                                        Icon(
                                          Icons.battery_std,
                                          size: 18,
                                          color: batteryLevel > 20
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                        const SizedBox(width: 6),
                                        // 👇 THIS is the key fix
                                        Expanded(
                                          child: Text(
                                            '$batteryLevel% ($state)',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: Responsive.getFontSize(
                                                context,
                                                baseSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // 👇 limit chip width
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 70,
                                          ),
                                          child: Card(
                                            color: Colors.blue,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 6 * scale,
                                                vertical: 3 * scale,
                                              ),
                                              child: Text(
                                                app,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize:
                                                      Responsive.getFontSize(
                                                        context,
                                                        baseSize: 11,
                                                      ),
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'Score',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        Text(
                                          score.toString(),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () => _showDeviceDetails(
                                      context,
                                      device,
                                      priority,
                                    ),
                                  ),
                                );
                              },
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: clientDevices.length,
                              itemBuilder: (context, index) {
                                final device = clientDevices[index];
                                final String app =
                                    device['app'] ?? 'Unknown IP';
                                final String deviceName =
                                    device['deviceName'] ?? 'No name';
                                final int batteryLevel =
                                    device['batteryLevel'] ?? 0;
                                final String state =
                                    device['batteryState'] ?? 'unknown';
                                final int priority = index + 1;
                                final int score = device['score'] ?? 0;
                                final Color rowColor = index.isEven
                                    ? Colors.grey.shade100
                                    : Colors.white;
                                return Card(
                                  color: rowColor,
                                  elevation: 0,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.zero,
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    title: Row(
                                      children: [
                                        // 🔵 Priority badge (top 5 only)
                                        if (priority > 0)
                                          Container(
                                            width: 32 * scale,
                                            height: 32 * scale,
                                            alignment: Alignment.center,
                                            decoration: const BoxDecoration(
                                              color: Colors.blue,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              priority.toString(),
                                              style: TextStyle(
                                                fontSize:
                                                    Responsive.getFontSize(
                                                      context,
                                                      baseSize: 14,
                                                    ),
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        const SizedBox(width: 12),
                                        // 🖥️ Client IP
                                        Expanded(
                                          child: Text(
                                            deviceName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: Responsive.getFontSize(
                                                context,
                                                baseSize: 16,
                                              ),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Row(
                                      children: [
                                        Icon(
                                          Icons.battery_std,
                                          size: 18,
                                          color: batteryLevel > 20
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                        const SizedBox(width: 6),
                                        // 👇 THIS is the key fix
                                        Expanded(
                                          child: Text(
                                            '$batteryLevel% ($state)',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: Responsive.getFontSize(
                                                context,
                                                baseSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // 👇 limit chip width
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 70,
                                          ),
                                          child: Card(
                                            color: Colors.blue,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 6 * scale,
                                                vertical: 3 * scale,
                                              ),
                                              child: Text(
                                                app,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize:
                                                      Responsive.getFontSize(
                                                        context,
                                                        baseSize: 11,
                                                      ),
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        const Text(
                                          'Score',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        Text(
                                          score.toString(),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () => _showDeviceDetails(
                                      context,
                                      device,
                                      priority,
                                    ),
                                  ),
                                );
                              },
                            ),
                  ],
                );
              },
            ),
          ),

          // Expanded(
          //   child: ValueListenableBuilder(
          //    valueListenable: Hive.box(
          //       'serverData',
          //     ).listenable(keys: ['allConnectedDevices']),
          //     builder: (context, Box box, _) {
          //       final List<dynamic> allDevices = box.get(
          //         'allConnectedDevices',
          //         defaultValue: <dynamic>[],
          //       );
          //       // Separate server and clients
          //       Map<String, dynamic>? serverDevice;
          //       List<Map<String, dynamic>> clientDevices = [];

          //       for (var device in allDevices) {
          //         final map = Map<String, dynamic>.from(device as Map);
          //         if (map['deviceType'] == 'server') {
          //           serverDevice = map;
          //         } else {
          //           clientDevices.add(map);
          //         }
          //       }

          //       // ✅ FIX: sort clients by priority
          //       clientDevices.sort((a, b) {
          //         final pa = a['priority'] ?? 9999;
          //         final pb = b['priority'] ?? 9999;
          //         return pa.compareTo(pb);
          //       });

          //       if (allDevices.isEmpty) {
          //         return Center(
          //           child: Column(
          //             mainAxisAlignment: MainAxisAlignment.center,
          //             children: [
          //               Icon(Icons.devices, size: 80, color: Colors.grey),
          //               SizedBox(height: 16),
          //               Text(
          //                 'No devices connected yet',
          //                 style: TextStyle(fontSize: 18, color: Colors.grey),
          //               ),
          //               Text(
          //                 'Waiting for clients to send data...',
          //                 style: TextStyle(color: Colors.grey),
          //               ),
          //             ],
          //           ),
          //         );
          //       }
          //       final String serverIp =
          //           serverDevice?['deviceName'] ?? 'Unknown IP';
          //       final int serverbatteryLevel =
          //           serverDevice?['batteryLevel'] ?? 0;
          //       final String serverstate =
          //           serverDevice?['batteryState'] ?? 'unknown';
          //       final double serverscore =
          //           serverDevice?['score']?.toDouble() ?? 0.0;
          //       final String app = serverDevice?['app'] ?? 'Unknown IP';

          //       return ListView(
          //         children: [
          //           // ────────────────── SERVER SECTION (if exists) ──────────────────
          //           if (serverDevice != null) ...[
          //             Card(
          //               color: Colors.white,
          //               elevation: 0,
          //               shape: const RoundedRectangleBorder(
          //                 borderRadius: BorderRadius.zero,
          //               ),
          //               child: ListTile(
          //                 contentPadding: const EdgeInsets.symmetric(
          //                   horizontal: 16,
          //                   vertical: 12,
          //                 ),
          //                 // leading: Icon(Icons.dns, size: 40, color: Colors.blue),
          //                 title: Column(
          //                   crossAxisAlignment: CrossAxisAlignment.start,
          //                   children: [
          //                     Text(
          //                       "Server",
          //                       style: const TextStyle(
          //                         fontSize: 20,
          //                         fontWeight: FontWeight.w600,
          //                       ),
          //                     ),
          //                     SizedBox(height: 10),
          //                     Row(
          //                       children: [
          //                         Icon(Icons.dns, size: 25, color: Colors.blue),
          //                         SizedBox(width: 8),
          //                         Text(
          //                           '$serverIp - $app',
          //                           style: const TextStyle(
          //                             fontSize: 16,
          //                             fontWeight: FontWeight.w600,
          //                           ),
          //                           maxLines: 1,
          //                         ),
          //                       ],
          //                     ),
          //                   ],
          //                 ),
          //                 subtitle: Column(
          //                   crossAxisAlignment: CrossAxisAlignment.start,
          //                   children: [
          //                     const SizedBox(height: 4),
          //                     // Text(
          //                     //   '$servermanufacturer $servermodel'.trim(),
          //                     // ),
          //                     // const SizedBox(height: 6),
          //                     Row(
          //                       children: [
          //                         Icon(
          //                           Icons.battery_std,
          //                           size: 18,
          //                           color: serverbatteryLevel > 20
          //                               ? Colors.green
          //                               : Colors.red,
          //                         ),
          //                         const SizedBox(width: 6),
          //                         Expanded(
          //                           child: Text(
          //                             '$serverbatteryLevel% ($serverstate)',
          //                             style: const TextStyle(fontSize: 13),
          //                             maxLines: 1,
          //                             overflow: TextOverflow.ellipsis,
          //                           ),
          //                         ),
          //                       ],
          //                     ),
          //                   ],
          //                 ),
          //                 trailing: Column(
          //                   mainAxisAlignment: MainAxisAlignment.center,
          //                   crossAxisAlignment: CrossAxisAlignment.end,
          //                   children: [
          //                     const Text(
          //                       'Score',
          //                       style: TextStyle(
          //                         fontSize: 12,
          //                         color: Colors.grey,
          //                       ),
          //                     ),
          //                     Text(
          //                       serverscore.toStringAsFixed(1),
          //                       style: const TextStyle(
          //                         fontSize: 18,
          //                         fontWeight: FontWeight.w600,
          //                         color: Colors.black87,
          //                       ),
          //                     ),
          //                   ],
          //                 ),
          //                 onTap: () =>
          //                     _showDeviceDetails(context, serverDevice!),
          //               ),
          //             ),
          //             const Divider(height: 1, color: Colors.grey),
          //           ],

          //           // ────────────────── CONNECTED DEVICES HEADING ──────────────────
          //           if (clientDevices.isNotEmpty)
          //             Padding(
          //               padding: const EdgeInsets.symmetric(
          //                 horizontal: 16,
          //                 vertical: 12,
          //               ),
          //               child: Text(
          //                 'Connected Clients (${clientDevices.length})',
          //                 style: TextStyle(
          //                   fontSize: 18,
          //                   fontWeight: FontWeight.bold,
          //                   color: Colors.grey[800],
          //                 ),
          //               ),
          //             ),

          //           // ────────────────── CLIENT DEVICES LIST ──────────────────
          //           if (clientDevices.isEmpty && serverDevice != null)
          //             const Center(
          //               child: Padding(
          //                 padding: EdgeInsets.all(32),
          //                 child: Text(
          //                   'No client devices connected yet',
          //                   style: TextStyle(color: Colors.grey, fontSize: 16),
          //                   textAlign: TextAlign.center,
          //                 ),
          //               ),
          //             )
          //           else
          //             appTypeNotifier.value == APP_SERVER
          //                 ? ReorderableListView.builder(
          //                     shrinkWrap: true,
          //                     physics: const NeverScrollableScrollPhysics(),
          //                     itemCount: clientDevices.length,

          //                     // 👇 IMPORTANT: we control drag manually
          //                     buildDefaultDragHandles: true,

          //                     // onReorder: (oldIndex, newIndex) async {
          //                     //   if (newIndex > oldIndex) newIndex--;

          //                     //   final movedClient = clientDevices[oldIndex];
          //                     //   final String clientIp = movedClient['clientIp'];

          //                     //   debugPrint(
          //                     //     '🔁 UI reorder: $clientIp from $oldIndex → $newIndex',
          //                     //   );

          //                     //   // Update UI immediately (optimistic UI)
          //                     //   final item = clientDevices.removeAt(oldIndex);
          //                     //   clientDevices.insert(newIndex, item);

          //                     //   // 🔑 IMPORTANT:
          //                     //   // +1 because server is index 0 in connectedDevices
          //                     //   final payload = {
          //                     //     'action': 'reorderClient',
          //                     //     'clientIp': clientIp,
          //                     //     'targetOrderIndex':
          //                     //         newIndex + 1, // desired position
          //                     //   };

          //                     //   debugPrint(
          //                     //     '📡 Sending reorder payload to server: $payload',
          //                     //   );

          //                     //   await sendataToServer(payload);
          //                     // },
          //                     onReorder: (oldIndex, newIndex) async {
          //                       if (newIndex > oldIndex) newIndex--;
          //                       final movedClient = clientDevices[oldIndex];
          //                       final String clientIp =
          //                           movedClient['deviceName']; // or clientIp

          //                       final payload = {
          //                         'action': 'reorderClient',
          //                         'clientIp': clientIp,
          //                         'targetOrderIndex': newIndex + 1,
          //                       };

          //                       // Send to server **first**
          //                       await sendataToServer(payload);

          //                       // Only after success → rely on Hive listener to rebuild
          //                       // Do **not** mutate clientDevices here
          //                     },

          //                     itemBuilder: (context, index) {
          //                       final device = clientDevices[index];

          //                       // 🔐 MUST be unique & stable
          //                       final String clientIp =
          //                           device['deviceName']; // REQUIRED
          //                       final int batteryLevel =
          //                           device['batteryLevel'] ?? 0;
          //                       final String state =
          //                           device['batteryState'] ?? 'unknown';
          //                       final int priority =
          //                           device['priority'] ?? (index + 1);
          //                       final double score =
          //                           device['score']?.toDouble() ?? 0.0;
          //                       final String app = device['app'] ?? 'Unknown';

          //                       // ❌ Disable drag if this is a CLIENT (or change condition)
          //                       final bool canDrag =
          //                           device['deviceType'] != 'client';

          //                       return Card(
          //                         key: ValueKey(
          //                           clientIp,
          //                         ), // ✅ FIXED KEY (NO DUPLICATES)
          //                         color: index.isEven
          //                             ? Colors.grey.shade100
          //                             : Colors.white,
          //                         elevation: 0,
          //                         shape: const RoundedRectangleBorder(
          //                           borderRadius: BorderRadius.zero,
          //                         ),
          //                         child: ListTile(
          //                           // 👇 Drag handle ONLY when allowed
          //                           leading: canDrag
          //                               ? ReorderableDragStartListener(
          //                                   index: index,
          //                                   child: const Icon(
          //                                     Icons.drag_handle,
          //                                   ),
          //                                 )
          //                               : const SizedBox(width: 24),

          //                           title: Row(
          //                             children: [
          //                               Container(
          //                                 width: 36,
          //                                 height: 36,
          //                                 alignment: Alignment.center,
          //                                 decoration: const BoxDecoration(
          //                                   color: Colors.blue,
          //                                   shape: BoxShape.circle,
          //                                 ),
          //                                 child: Text(
          //                                   priority.toString(),
          //                                   style: const TextStyle(
          //                                     color: Colors.white,
          //                                     fontWeight: FontWeight.bold,
          //                                   ),
          //                                 ),
          //                               ),
          //                               const SizedBox(width: 12),
          //                               Text(
          //                                 '$clientIp - $app',
          //                                 style: const TextStyle(
          //                                   fontSize: 16,
          //                                   fontWeight: FontWeight.w600,
          //                                 ),
          //                               ),
          //                             ],
          //                           ),

          //                           subtitle: Row(
          //                             children: [
          //                               const SizedBox(width: 40),
          //                               Icon(
          //                                 Icons.battery_std,
          //                                 size: 18,
          //                                 color: batteryLevel > 20
          //                                     ? Colors.green
          //                                     : Colors.red,
          //                               ),
          //                               const SizedBox(width: 6),
          //                               Text(
          //                                 '$batteryLevel% ($state)',
          //                                 style: const TextStyle(fontSize: 13),
          //                               ),
          //                             ],
          //                           ),

          //                           trailing: Column(
          //                             mainAxisAlignment:
          //                                 MainAxisAlignment.center,
          //                             children: [
          //                               const Text(
          //                                 'Score',
          //                                 style: TextStyle(
          //                                   fontSize: 12,
          //                                   color: Colors.grey,
          //                                 ),
          //                               ),
          //                               Text(
          //                                 score.toStringAsFixed(1),
          //                                 style: const TextStyle(
          //                                   fontSize: 18,
          //                                   fontWeight: FontWeight.w600,
          //                                 ),
          //                               ),
          //                             ],
          //                           ),

          //                           onTap: () =>
          //                               _showDeviceDetails(context, device),
          //                         ),
          //                       );
          //                     },
          //                   )
          //                 : ListView.builder(
          //                     shrinkWrap: true,
          //                     physics: const NeverScrollableScrollPhysics(),
          //                     itemCount: clientDevices.length,
          //                     itemBuilder: (context, index) {
          //                       final device = clientDevices[index];

          //                       final String clientIp =
          //                           device['deviceName'] ?? 'Unknown IP';
          //                       final int batteryLevel =
          //                           device['batteryLevel'] ?? 0;
          //                       final String state =
          //                           device['batteryState'] ?? 'unknown';
          //                       final int priority = device['priority'] ?? 0;
          //                       final double score =
          //                           device['score']?.toDouble() ?? 0.0;
          //                       final String app =
          //                           device['app'] ?? 'Unknown App';

          //                       final Color rowColor = index.isEven
          //                           ? Colors.grey.shade100
          //                           : Colors.white;

          //                       return Card(
          //                         color: rowColor,
          //                         elevation: 0,
          //                         shape: const RoundedRectangleBorder(
          //                           borderRadius: BorderRadius.zero,
          //                         ),
          //                         child: ListTile(
          //                           contentPadding: const EdgeInsets.symmetric(
          //                             horizontal: 16,
          //                             vertical: 12,
          //                           ),
          //                           title: Row(
          //                             children: [
          //                               // Only show priority badge if in top 5
          //                               if (priority > 0)
          //                                 Container(
          //                                   width: 36,
          //                                   height: 36,
          //                                   alignment: Alignment.center,
          //                                   decoration: BoxDecoration(
          //                                     color: priority <= 3
          //                                         ? Colors.blue
          //                                         : Colors.grey,
          //                                     shape: BoxShape.circle,
          //                                   ),
          //                                   child: Text(
          //                                     priority.toString(),
          //                                     style: const TextStyle(
          //                                       color: Colors.white,
          //                                       fontWeight: FontWeight.bold,
          //                                       fontSize: 16,
          //                                     ),
          //                                   ),
          //                                 )
          //                               else
          //                                 Container(
          //                                   width: 36,
          //                                   height: 36,
          //                                   alignment: Alignment.center,
          //                                   child: Icon(
          //                                     Icons.circle,
          //                                     size: 12,
          //                                     color: Colors.grey[400],
          //                                   ),
          //                                 ),

          //                               const SizedBox(width: 12),
          //                               Text(
          //                                 '${clientIp} - $app',
          //                                 style: const TextStyle(
          //                                   fontSize: 16,
          //                                   fontWeight: FontWeight.w600,
          //                                 ),
          //                               ),
          //                             ],
          //                           ),
          //                           subtitle: Column(
          //                             crossAxisAlignment:
          //                                 CrossAxisAlignment.start,
          //                             children: [
          //                               const SizedBox(height: 4),
          //                               // Text('$manufacturer $model'.trim()),
          //                               // const SizedBox(height: 6),
          //                               Row(
          //                                 children: [
          //                                   Icon(
          //                                     Icons.battery_std,
          //                                     size: 18,
          //                                     color: batteryLevel > 20
          //                                         ? Colors.green
          //                                         : Colors.red,
          //                                   ),
          //                                   const SizedBox(width: 6),
          //                                   Expanded(
          //                                     child: Text(
          //                                       '$batteryLevel% ($state)',
          //                                       style: const TextStyle(
          //                                         fontSize: 13,
          //                                       ),
          //                                     ),
          //                                   ),
          //                                 ],
          //                               ),
          //                             ],
          //                           ),
          //                           trailing: Column(
          //                             mainAxisAlignment:
          //                                 MainAxisAlignment.center,
          //                             crossAxisAlignment:
          //                                 CrossAxisAlignment.end,
          //                             children: [
          //                               const Text(
          //                                 'Score',
          //                                 style: TextStyle(
          //                                   fontSize: 12,
          //                                   color: Colors.grey,
          //                                 ),
          //                               ),
          //                               Text(
          //                                 score.toStringAsFixed(1),
          //                                 style: const TextStyle(
          //                                   fontSize: 18,
          //                                   fontWeight: FontWeight.w600,
          //                                   color: Colors.black87,
          //                                 ),
          //                               ),
          //                             ],
          //                           ),
          //                           onTap: () =>
          //                               _showDeviceDetails(context, device),
          //                         ),
          //                       );
          //                     },
          //                   ),
          //         ],
          //       );
          //     },
          //   ),
          // ),
        ],
      ),
    );
  }

  void _showDeviceDetails(
    BuildContext context,
    Map<String, dynamic> device,
    int priority,
  ) {
    final String deviceType = device['deviceType'] ?? 'client';
    final String deviceName = device['deviceName'] ?? 'No name';
    final String app = device['app'] ?? 'Unknown';
    final String clientIp = device['clientIp'] ?? 'Unknown IP';
    final String model = device['model'] ?? 'Unknown';
    final String manufacturer = device['manufacturer'] ?? '';
    final int batteryLevel =
        int.tryParse(device['batteryLevel']?.toString() ?? '0') ?? 0;
    final String batteryState = device['batteryState'] ?? 'unknown';
    final String osVersion = device['osVersion'] ?? 'Unknown OS';
    final int score = int.tryParse(device['score']?.toString() ?? '0') ?? 0;
    final double totalRamGB = _toDouble(device['totalRamGB']);
    final double freeRamGB = _toDouble(device['freeRamGB']);
    final double totalStorageGB = _toDouble(device['totalStorageGB']);
    final double freeStorageGB = _toDouble(device['freeStorageGB']);
    final int dailyAppUsageMinutes =
        int.tryParse(device['dailyAppUsageMinutes']?.toString() ?? '0') ?? 0;
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
              _detailRow('Device Name', deviceName),
              _detailRow('IP Address', clientIp),
              _detailRow('Device type', app),
              _detailRow('Manufacturer', manufacturer.trim()),
              _detailRow('Model', model.trim()),
              _detailRow('OS Version', osVersion),
              _detailRow('RAM', '${totalRamGB.toStringAsFixed(1)} GB'),
              _detailRow('Free RAM', '${freeRamGB.toStringAsFixed(1)} GB'),
              _detailRow('Storage', '${totalStorageGB.toStringAsFixed(1)} GB'),
              _detailRow(
                'Free Storage',
                '${freeStorageGB.toStringAsFixed(1)} GB',
              ),
              _detailRow('Battery', '$batteryLevel% ($batteryState)'),
              _detailRow('Daily Usage', '$dailyAppUsageMinutes minutes'),
              _detailRow('Performance Score', score.toString()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CLOSE',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
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
            child: Text(value, style: const TextStyle(color: Colors.black87)),
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
