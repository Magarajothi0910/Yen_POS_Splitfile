import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pax_provider.dart';

// 🏗️ Build a dropdown for selecting pax (dynamic)
Widget buildPaxDropdown(
  BuildContext context, {
  required int maxPax, // 👈 dynamic pax limit (seat count)
  void Function(String?)? onChanged,
}) {
  return Container(
    decoration: BoxDecoration(
      border: Border.all(color: Colors.black12, width: 1.5),
      borderRadius: BorderRadius.circular(8.0),
      color: Colors.white,
    ),
    child: DropdownButtonHideUnderline(
      child: Consumer<PaxProviderDine>(
        builder: (context, paxProvider, child) {
          return DropdownButton<String>(
            value: paxProvider.selectedPax,
            onChanged: (String? newValue) {
              if (newValue != null) {
                paxProvider.setSelectedPax(newValue);
                onChanged?.call(newValue);
                print('👥 Pax selected: $newValue');
              }
            },

            // 🔁 Dynamic pax list
            items: [
              ...List.generate(
                maxPax,
                (index) {
                  final value = (index + 1).toString();
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      "Pax $value",
                      style: const TextStyle(fontSize: 14, color: Colors.black),
                    ),
                  );
                },
              ),

              // ➕ Max+ option
              DropdownMenuItem<String>(
                value: "$maxPax+",
                child: Text(
                  "Pax $maxPax+",
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                ),
              ),
            ],

            hint: const Text(
              'Select Pax',
              style: TextStyle(fontSize: 14, color: Colors.black12),
            ),
            style: const TextStyle(color: Colors.black, fontSize: 14),
            dropdownColor: Colors.white,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
            isExpanded: true,
            itemHeight: null, // 🔔 fixes kMinInteractiveDimension issue
            padding: const EdgeInsets.symmetric(horizontal: 14),
          );
        },
      ),
    ),
  );
}
