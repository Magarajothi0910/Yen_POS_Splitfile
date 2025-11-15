import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/kotpreinvoice/providers/pax_provider.dart';


// 🏗️ Build a dropdown for selecting pax
Widget buildPaxDropdown(BuildContext context, {void Function(String?)? onChanged}) {
  return Container(
    decoration: BoxDecoration(
      border: Border.all(color: Colors.black12, width: 1.5),
      borderRadius: BorderRadius.circular(4.0),
      color: Colors.white,
    ),
    child: DropdownButtonHideUnderline(
      child: Consumer<PaxProviderDine>(
        builder: (context, paxProvider, child) {
          return SizedBox(
            height: 40,
            child : DropdownButton<String>(
            value: paxProvider.selectedPax,
            onChanged: (String? newValue) {
              if (newValue != null) {
                paxProvider.setSelectedPax(newValue); // 👥 Update PaxProvider
                onChanged?.call(newValue); // 📌 Notify parent via callback
                print('👥 Pax selected: $newValue');
              }
            },
            items: List.generate(10, (index) => (index + 1).toString()).map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(
                  "Pax $value",
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                ),
              );
            }).toList()
              ..add(
                const DropdownMenuItem<String>(
                  value: "10+",
                  child: Text(
                    "Pax 10+",
                    style: TextStyle(fontSize: 14, color: Colors.black),
                  ),
                ),
              ),
            hint: const Text(
              'Select Pax',
              style: TextStyle(fontSize: 14, color: Colors.black12),
            ),
            style: const TextStyle(color: Colors.black, fontSize: 14),
            dropdownColor: Colors.white,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
            isExpanded: true,
            // itemHeight: null, // 🔔 Set to null to fix kMinInteractiveDimension error
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          );
        },
      ),
    ),
  );
}
