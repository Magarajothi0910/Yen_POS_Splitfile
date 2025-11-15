import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';


import 'package:yenpos/Global/globals_data.dart';

class EditVarianceDialog extends StatefulWidget {
  final Map<String, dynamic> order;
  final int i;
  final List<String> allAddOns;

  const EditVarianceDialog({
    Key? key,
    required this.order,
    required this.i,
    required this.allAddOns,
  }) : super(key: key);

  @override
  State<EditVarianceDialog> createState() => _EditVarianceDialogState();
}

class _EditVarianceDialogState extends State<EditVarianceDialog> {
  late List<Map<String, dynamic>> config;
  late List<double> quantities;
  late List<TextEditingController> remarkControllers;
  late List<ValueNotifier<bool>> isParcelNotifiers;
  late List<ValueNotifier<bool>> toggleRemarkNotifiers;

  WebSocketChannel? channel;

  @override
  void initState() {
    super.initState();

    // Initialize the WebSocket channel
    channel = WebSocketChannel.connect(
      Uri.parse('ws://$serverip:$port'),
    );

    // Optionally listen to incoming messages
    // channel.stream.listen((message) {});
  }

  @override
  void dispose() {
    // Close the WebSocket connection when the widget is disposed
    channel?.sink.close();
    super.dispose();
  }

  Future<void> sendMessage(Map<String, dynamic> configDetails) async {
    try {
      final jsonData = jsonEncode(configDetails);
      channel?.sink.add(jsonData);
      print("✅ Message sent successfully: $jsonData");
    } catch (error, stackTrace) {
      print("❌ Error while sending message: $error");
      print("📝 Stack trace: $stackTrace");
    }
  }

  @override
  Widget build(BuildContext context) {
    config = List<Map<String, dynamic>>.from(widget.order['config']);
    quantities = List<double>.from(widget.order['quantities']);
    //         List<Map<String, dynamic>>
    //             config = List<
    //                     Map<String,
    //                         dynamic>>.from(
    //                 order['config']);
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Center(
        child: Text(
          "Edit  ${widget.order['varianceNames'][widget.i]}",
          style: const TextStyle(fontSize: 15),
        ),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(widget.order[widget.i]['configQty'].length, (index) {
                // Extract data for each quantity row
                List<String> addons = List<String>.from(widget.order[widget.i]['addOn'][index]);
                List<int> addonquantity = List<int>.from(widget.order[widget.i]['addOnQuantity'][index]);
                String selectedVariant = widget.order[widget.i]['variance'][index];
                String type = widget.order[widget.i]['type'][index];
                String remark = widget.order[widget.i]['remark'][index];

                // Controllers and notifiers
                TextEditingController remarkController = TextEditingController(text: remark);
                ValueNotifier<bool> isParcelNotifier = ValueNotifier<bool>(type == "Parcel");
                ValueNotifier<bool> toggleRemarkNotifier = ValueNotifier<bool>(remark.isNotEmpty);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Text(
                              '${index + 1}. ${widget.order['varianceNames'][widget.i]}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                            onPressed: () {
                              // Ensure the quantity and configQty are valid before decrementing
                              if (quantities[widget.i] > 0 && widget.order[widget.i]['configQty'][index] > 0) {
                                // Decrement the quantity
                                quantities[widget.i] -= 1;

                                // Decrement the corresponding index in configQty
                                widget.order[widget.i]['configQty'][index] -= 1;
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.blue),
                            onPressed: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          if (widget.allAddOns.isNotEmpty)
                            if (widget.order[widget.i]['variance'].where((v) => v.toString().trim().isNotEmpty && v.toLowerCase() != "default").isNotEmpty)
                              SizedBox(
                                width: 120,
                                child: DropdownButton<String>(
                                  value: selectedVariant,
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: "",
                                      child: Text(""),
                                    ),
                                    ...widget.order[widget.i]['variance'].where((v) => v.toString().trim().isNotEmpty).toSet().map<DropdownMenuItem<String>>((value) {
                                      return DropdownMenuItem<String>(
                                        value: value.toString(),
                                        child: Text(value.toString()),
                                      );
                                    }).toList(),
                                  ],
                                  onChanged: (newValue) {
                                    widget.order[widget.i]['variance'][index] = newValue!;
                                  },
                                ),
                              ),
                          ValueListenableBuilder<bool>(
                            valueListenable: isParcelNotifier,
                            builder: (context, isParcel, child) {
                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: isParcel,
                                        onChanged: (value) {
                                          isParcelNotifier.value = value!;
                                          widget.order[widget.i]['type'][index] = value ? "Parcel" : "";
                                        },
                                        activeColor: Colors.blue,
                                        checkColor: Colors.white,
                                      ),
                                    ],
                                  ),
                                  const Text(
                                    "Parcel",
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                                  ),
                                ],
                              );
                            },
                          ),
                          ValueListenableBuilder<bool>(
                            valueListenable: toggleRemarkNotifier,
                            builder: (context, toggleRemark, child) {
                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      Switch(
                                        value: toggleRemark,
                                        onChanged: (value) {
                                          toggleRemarkNotifier.value = value;
                                          if (!value) {
                                            remarkController.clear();
                                            widget.order[widget.i]['remark'][index] = "";
                                          }
                                        },
                                        activeColor: Colors.blue,
                                      ),
                                    ],
                                  ),
                                  const Text(
                                    "Remark: ",
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: toggleRemarkNotifier,
                        builder: (context, toggleRemark, child) {
                          return toggleRemark
                              ? TextField(
                                  controller: remarkController,
                                  decoration: const InputDecoration(
                                    labelText: 'Remark',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (value) {
                                    widget.order[widget.i]['remark'][index] = value;
                                  },
                                )
                              : const SizedBox();
                        },
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text('OK'),
          onPressed: () async {
            try {
              ValueNotifier<List<double>> quantitiesNotifier = ValueNotifier<List<double>>(quantities);
              ValueNotifier<List<Map<String, dynamic>>> configNotifier = ValueNotifier<List<Map<String, dynamic>>>(config);
              widget.order['config'] = config;
              widget.order['quantities'] = quantities; // Notify the quantities field
              String seathiveOrderId = widget.order['seathiveOrderId']; // Assuming this is part of the `order`

              // Notify listeners of the change
              quantitiesNotifier.value = [...quantities];
              configNotifier.value = [...config];
              // Prepare data to send to the server
              Map<String, dynamic> configDetails = {
                'action': "updateConfigDetails",
                'seathiveOrderId': seathiveOrderId,
                'config': config,
                'quantities': quantities,
              };

              // Log the configDetails for debugging

              sendMessage(configDetails);

              Navigator.of(context).pop();
            } catch (error) {
              // Handle exceptions
            }
          },
        ),
      ],
    );
  }
}
