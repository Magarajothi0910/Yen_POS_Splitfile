import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kotproviders/pax_provider.dart'; // Import the provider

Widget buildPaxDropdown(BuildContext context) {
  return Container(
    decoration: BoxDecoration(
      border: Border.all(
        color: Colors.black12, // Border color
        width: 1.5,
      ),
      borderRadius: BorderRadius.circular(8.0), // Rounded border
      color: Colors.white, // Dropdown background color
    ),
    child: DropdownButtonHideUnderline(
      child: Consumer<PaxProvider>(
        builder: (context, paxProvider, child) {
          return DropdownButton<String>(
            value: paxProvider.selectedPax,
            onChanged: (String? newValue) {
              if (newValue != null) {
                paxProvider.setSelectedPax(newValue);
              }
            },
            items: List.generate(10, (index) => (index + 1).toString())
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text("Pax $value"),
              );
            }).toList()
              ..add(
                const DropdownMenuItem<String>(
                  value: "10+",
                  child: Text("Pax 10+"),
                ),
              ),
          );
        },
      ),
    ),
  );
}




// Widget buildPaxDropdown(BuildContext context) {
//   return Container(
//     padding: const EdgeInsets.symmetric(horizontal: 10),
//     decoration: BoxDecoration(
//       border: Border.all(
//         width: 1, // Border width
//       ),
//       borderRadius: BorderRadius.circular(8.0), // Rounded corners
//     ),
//     child: SizedBox(
//       width: 80,
//       child: DropdownButtonHideUnderline(
//         child: Consumer<PaxProvider>(
//           builder: (context, paxProvider, child) {
//             return DropdownButton<String>(
//               value: paxProvider.selectedPax,
//               isExpanded: true, // Makes dropdown full-width
//               icon: const Icon(Icons.arrow_drop_down), // Dropdown arrow
//               style: const TextStyle(
//                 color: Colors.black, // Text color
//                 fontSize: 14, // Font size
//               ),
//               onChanged: (String? newValue) {
//                 if (newValue != null) {
//                   paxProvider.setSelectedPax(newValue);
//                 }
//               },
//               items: List.generate(10, (index) => (index + 1).toString())
//                   .map<DropdownMenuItem<String>>((String value) {
//                 return DropdownMenuItem<String>(
//                   value: value,
//                   child: Text("Pax $value"),
//                 );
//               }).toList()
//                 ..add(
//                   const DropdownMenuItem<String>(
//                     value: "10+",
//                     child: Text("Pax 10+"),
//                   ),
//                 ),
//             );
//           },
//         ),
//       ),
//     ),
//   );
// }
