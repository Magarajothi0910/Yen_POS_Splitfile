import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:yenposapp/Global/glassmorphisom.dart';
import '../../../Global/custom_textWidgets.dart';
import '../../../data/global_data_manager.dart';
import '../../more_page/providers/bt_provide2.dart';
import '../model/variance.dart';
import '../provider/cart_page_provider.dart';
import '../provider/quantity_provider.dart';

void disposeLargeObjects(BuildContext context) {
  selectedVariances.clear();
  // weight2 = "";
  // Reset the quantity in the QuantityProvider
  Provider.of<QuantityProvider>(context, listen: false).setQuantity(1);
}

String weight2 = "";
// Assuming each variance has a unique identifier, we use this in our map.
Map<String, bool> selectedVariances = {};

void showVarianceDialog(
    BuildContext context, List<Variance> variances, String itemName) {
  showDialog(
    // barrierColor: Colors.transparent,
    context: context,
    builder: (BuildContext context) {
      for (Variance variance in variances) {
        if (!selectedVariances.containsKey(variance.varianceName)) {
          selectedVariances[variance.varianceName] = false;
        }
      }

      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            backgroundColor:
                Colors.transparent, // Set to transparent to allow glass effect

            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),

            content: GlassMorphism(
              blur: 10.0, // Adjust the blur effect for the glass look
              opacity: 0.2, // Adjust opacity to get the glass effect
              color:
                  Colors.white, // The color can be changed based on preference
              borderRadius:
                  BorderRadius.circular(12.0), // Optional for rounded corners
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                            onPressed: () {
                              disposeLargeObjects(context);
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 30,
                            )),
                        Text(itemName,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 30)),
                        ElevatedButton(
                          onPressed: () async {
                            final quantity = Provider.of<QuantityProvider>(
                                    context,
                                    listen: false)
                                .quantity;

                            final selectedVariance = variances.firstWhere(
                              (variance) =>
                                  selectedVariances[variance.varianceName]!,
                            );

                            final itemData = GlobalDataManager()
                                .branchwiseItems['data'][itemName]['item'];
                            final varianceData = GlobalDataManager()
                                    .branchwiseItems['data'][itemName]
                                ['variance'][selectedVariance.varianceName];

                            var box = await Hive.openBox('cartBox');
                            List<Map<String, dynamic>> cartItems = box
                                    .get('cartItems', defaultValue: [])?.cast<
                                        Map<String, dynamic>>() ??
                                [];

                            // Check if the item with the same variance already exists in the cart
                            bool itemExists = false;
                            for (var cartItem in cartItems) {
                              if (cartItem['itemData']['itemId'] ==
                                      itemData['itemId'] &&
                                  cartItem['varianceData']['varianceName'] ==
                                      varianceData['varianceName']) {
                                // Update quantity
                                cartItem['quantity'] += quantity;
                                itemExists = true;
                                break;
                              }
                            }

                            if (!itemExists) {
                              cartItems.add({
                                'itemData': itemData,
                                'varianceData': varianceData,
                                'quantity': quantity,
                              });
                              // Print the data when a new item is added
                            }

                            await box.put('cartItems', cartItems);
                            Map<String, dynamic> newItem = {
                              'itemData': itemData,
                              'varianceData': varianceData,
                              'quantity': quantity,
                            };
                            Provider.of<CurrentSaleProvider>(context,
                                    listen: false)
                                .addItemToCart(newItem);

                            Provider.of<CurrentSaleProvider>(context,
                                    listen: false)
                                .loadCartItems();
                            disposeLargeObjects(context);

                            Navigator.of(context).pop();
                          },
                          style: ButtonStyle(
                            shape: WidgetStateProperty.all(
                                RoundedRectangleBorder(
                                    borderRadius: BorderRadius.zero)),
                            backgroundColor:
                                WidgetStateProperty.all(Colors.transparent),
                          ),
                          child: const Text('Add',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 20)),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 300,
                      width: 500,
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 4,
                        ),
                        itemCount: variances.length,
                        itemBuilder: (context, index) {
                          final variance = variances[index];
                          return GestureDetector(
                            onTap: () async {
                              setState(() {
                                // Deselect all variances first
                                selectedVariances
                                    .updateAll((key, value) => false);

                                // Select the tapped variance
                                selectedVariances[variance.varianceName] =
                                    !selectedVariances[variance.varianceName]!;
                              });

                              if (selectedVariances[variance.varianceName]!) {
                                final varianceUOM = GlobalDataManager()
                                    .branchwiseItems['data']
                                    .entries
                                    .firstWhere((entry) =>
                                        entry.value['variance'] != null &&
                                        entry.value['variance'].values.any(
                                            (v) =>
                                                v['varianceName'] ==
                                                variance.varianceName))
                                    .value['variance']
                                    .entries
                                    .firstWhere((v) =>
                                        v.value['varianceName'] ==
                                        variance.varianceName)
                                    .value['variance_Uom'];


                                if (varianceUOM.toLowerCase() == 'kg' ||
                                    varianceUOM.toLowerCase() == 'kgs') {
                                  showWeightDialog(
                                      context,
                                      itemName,
                                      variance.varianceName,
                                      variance.varianceDefaultPrice);
                                }
                              }
                            },
                            child: buildVarianceTile(variance),
                          );
                        },
                      ),
                    ),
                    Column(
                      children: [
                        SizedBox(height: 8),
                        const Text(
                          "QUANTITY",
                          style: TextStyle(color: Colors.white, fontSize: 20),
                        ),
                        SizedBox(height: 4),
                        QuantitySelector(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Widget buildVarianceTile(Variance variance) {
  bool isSelected = selectedVariances[variance.varianceName] ?? false;
  return RepaintBoundary(
    child: Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color.fromARGB(255, 58, 58, 59)
            : Colors.grey[200],
        border: Border.all(
            color: isSelected
                ? const Color.fromARGB(255, 58, 58, 59)
                : Colors.black12),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: CustomText(
              text: variance.varianceName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
          ),
          CustomText(
            text: '₹ ${variance.varianceDefaultPrice}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    ),
  );
}

class QuantitySelector extends StatefulWidget {
  @override
  _QuantitySelectorState createState() => _QuantitySelectorState();
}

class _QuantitySelectorState extends State<QuantitySelector> {
  late TextEditingController quantityController;
  late FocusNode quantityFocusNode;

  @override
  void initState() {
    super.initState();
    quantityController = TextEditingController(text: '1');
    quantityFocusNode = FocusNode();
  }

  @override
  void dispose() {
    quantityController.dispose();
    quantityFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QuantityProvider>(
      builder: (context, quantityProvider, child) {
        return RepaintBoundary(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Decrease quantity button
                IconButton(
                  iconSize: 40,
                  icon: Icon(Icons.remove,
                      color: quantityProvider.quantity > 1
                          ? Colors.white
                          : Colors.white),
                  onPressed: () {
                    quantityProvider.decrement();
                    quantityController.text =
                        quantityProvider.quantity.toString();
                  },
                ),
                Flexible(
                  child: TextField(
                    controller: quantityController,
                    focusNode: quantityFocusNode, // Binding the FocusNode
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly, // Only digits
                      LengthLimitingTextInputFormatter(5), // Max 5 digits
                    ],
                    decoration: const InputDecoration(border: InputBorder.none),
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        int quantity = int.tryParse(value) ?? 1;
                        quantityProvider.setQuantity(quantity);
                      }
                    },
                  ),
                ),
                IconButton(
                  iconSize: 40,
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () {
                    quantityProvider.increment();
                    quantityController.text =
                        quantityProvider.quantity.toString();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

void showWeightDialog(
    BuildContext context, String itemName, String varianceName, double price) {

  final bluetoothProvider2 =
      Provider.of<BluetoothProvider2>(context, listen: false);

  // Check if Bluetooth is connected
  if (!bluetoothProvider2.isConnected) {
    // Show a dialog prompting to connect Bluetooth
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Bluetooth Not Connected"),
          content:
              const Text("Please connect to a Bluetooth device to proceed."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
    return; // Exit the function if Bluetooth is not connected
  }

  // Proceed with the weight dialog if Bluetooth is connected
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        backgroundColor: Colors.white,
        title: CustomText(
          text: varianceName,
          style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
        ),
        content: Consumer<BluetoothProvider2>(
          builder: (context, bluetoothProvider2, child) {
            double weight = bluetoothProvider2.weight;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Weight: ${weight.toStringAsFixed(3)} kg",
                  style: const TextStyle(fontSize: 24),
                ),
              ],
            );
          },
        ),
        actions: <Widget>[
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              double weight =
                  Provider.of<BluetoothProvider2>(context, listen: false)
                      .weight;

              if (weight <= 0) {
                return;
              }


              final itemData =
                  GlobalDataManager().branchwiseItems['data'][itemName]['item'];
              final varianceData = GlobalDataManager().branchwiseItems['data']
                  [itemName]['variance'][varianceName];
              double totalPrice = price * weight;

              var box = await Hive.openBox('cartBox');
              List<Map<String, dynamic>> cartItems = box.get('cartItems',
                      defaultValue: [])?.cast<Map<String, dynamic>>() ??
                  [];

              cartItems.add({
                'itemData': itemData,
                'varianceData': varianceData,
                'quantity': weight,
                'totalPrice': totalPrice,
              });

              await box.put('cartItems', cartItems);
              Provider.of<CurrentSaleProvider>(context, listen: false)
                  .loadCartItems();

              disposeLargeObjects(context);

              Navigator.of(context).pop();
            },
            style: ButtonStyle(
              shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
              backgroundColor: WidgetStateProperty.all(Colors.blue),
            ),
            child: const CustomText(
              text: 'Add',
              style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
        ],
      );
    },
  );
}

void showWeightDialogformixed(
    BuildContext context, String itemName, String varianceName, double price,
    {required Function(double) onWeightSelected}) {
  final bluetoothProvider2 =
      Provider.of<BluetoothProvider2>(context, listen: false);

  // Check if Bluetooth is connected
  if (!bluetoothProvider2.isConnected) {
    // Show a dialog prompting to connect Bluetooth
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Bluetooth Not Connected"),
          content:
              const Text("Please connect to a Bluetooth device to proceed."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
    return; // Exit the function if Bluetooth is not connected
  }
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        backgroundColor: Colors.white,
        title: Text(
          varianceName,
          style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
        ),
        content: Consumer<BluetoothProvider2>(
          builder: (context, bluetoothProvider2, child) {
            double weight = bluetoothProvider2.weight;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Weight: ${weight.toStringAsFixed(2)} kg",
                  style: const TextStyle(fontSize: 24),
                ),
              ],
            );
          },
        ),
        actions: <Widget>[
          ElevatedButton(
            onPressed: () async {
              // Retrieve the current weight
              double weight =
                  Provider.of<BluetoothProvider2>(context, listen: false)
                      .weight;

              // Check if weight is zero or not provided
              if (weight <= 0) {
                return;
              }

              // Calculate total price based on the weight
              double totalPrice = price * weight;

              // Print the weight and total price

              // Call the callback to pass the weight back to the dialog
              onWeightSelected(weight);

              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              backgroundColor: Colors.blue,
            ),
            child: const Text(
              'Add',
              style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
        ],
      );
    },
  );
}

void showWeightDialogforVariances(
    BuildContext context, String itemName, String varianceName, double price,
    {required Function(double) onWeightSelected}) {
  final bluetoothProvider2 =
      Provider.of<BluetoothProvider2>(context, listen: false);

  // Check if Bluetooth is connected
  if (!bluetoothProvider2.isConnected) {
    // Show a dialog prompting to connect Bluetooth
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Bluetooth Not Connected"),
          content:
              const Text("Please connect to a Bluetooth device to proceed."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
    return; // Exit the function if Bluetooth is not connected
  }
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        backgroundColor: Colors.white,
        title: Text(
          varianceName,
          style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
        ),
        content: Consumer<BluetoothProvider2>(
          builder: (context, bluetoothProvider2, child) {
            double weight = bluetoothProvider2.weight;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Weight: ${weight.toStringAsFixed(2)} kg",
                  style: const TextStyle(fontSize: 24),
                ),
              ],
            );
          },
        ),
        actions: <Widget>[
          ElevatedButton(
            onPressed: () async {
              // Retrieve the current weight
              double weight =
                  Provider.of<BluetoothProvider2>(context, listen: false)
                      .weight;

              // Check if weight is zero or not provided
              if (weight <= 0) {
                return;
              }

              // Calculate total price based on the weight
              double totalPrice = price * weight;

              // Print the weight and total price

              // Call the callback to pass the weight back to the dialog
              onWeightSelected(weight);

              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              backgroundColor: Colors.blue,
            ),
            child: const Text(
              'Add',
              style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
        ],
      );
    },
  );
}
