import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class ViewInvoiceBoxScreen extends StatelessWidget {
  const ViewInvoiceBoxScreen({super.key});

  Widget buildDataTable(Map<dynamic, dynamic> invoice) {
    List<DataRow> rows = [];

    invoice.forEach((key, value) {
      if (value is List) {
        // If the value is a list, create a single cell with all items concatenated
        rows.add(DataRow(cells: [
          DataCell(Text(key.toString())),
          DataCell(Text(value.join(', '))), // Join list items with a comma
        ]));
      } else {
        // For regular values, just show them in their respective cells
        rows.add(DataRow(cells: [
          DataCell(Text(key.toString())),
          DataCell(Text(value.toString())),
        ]));
      }
    });

    return DataTable(columns: const [
      DataColumn(label: Text('Field')),
      DataColumn(label: Text('Value')),
    ], rows: rows);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View All Invoices'),
      ),
      body: FutureBuilder<Box>(
        future: Hive.openBox('invoiceBox'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.error != null) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else {
              var box = snapshot.data!;
              if (box.isEmpty) {
                return const Center(child: Text("No invoices found"));
              }
              return ListView.builder(
                itemCount: box.length,
                itemBuilder: (context, index) {
                  final invoice = box.getAt(index) as Map<dynamic, dynamic>;
                  return Card(
                    child: ExpansionTile(
                      leading: const Icon(Icons.receipt),
                      title: Text(
                          'Invoice ID: ${invoice['id']} - \$${invoice['total']}'),
                      children: [buildDataTable(invoice)],
                    ),
                  );
                },
              );
            }
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
