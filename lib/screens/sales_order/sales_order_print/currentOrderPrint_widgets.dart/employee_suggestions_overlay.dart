import 'package:flutter/material.dart';

class EmployeeSuggestionsOverlay extends StatelessWidget {
  final List<Map<String, dynamic>> suggestions;
  final Function(Map<String, dynamic>) onSelect;
  final OverlayEntry? overlayEntry;

  const EmployeeSuggestionsOverlay({
    super.key,
    required this.suggestions,
    required this.onSelect,
    required this.overlayEntry,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 210.0,
      left: 340.0,
      right: 650.0,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 100,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              final employee = suggestions[index];
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(
                  '${employee['employeeNumber']} - ${employee['firstName']}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () => onSelect(employee),
              );
            },
          ),
        ),
      ),
    );
  }
}
