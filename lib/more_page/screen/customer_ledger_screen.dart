import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/more_page/providers/customer_provider.dart';

class CustomerLedgerScreen extends StatefulWidget {
  final String customerPhoneNumber;
  final String customerName;

  const CustomerLedgerScreen({
    super.key,
    required this.customerPhoneNumber,
    required this.customerName,
  });

  @override
  _CustomerLedgerScreenState createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen> {
  bool _isFetched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isFetched) {
      final provider = context.read<CustomerProvider>();
      provider.fetchLedger(widget.customerPhoneNumber);
      _isFetched = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "${widget.customerName} Ledger",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.blue.shade800,
        elevation: 6,
      ),
      backgroundColor: Colors.grey.shade100,
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.ledger.isEmpty
          ? const Center(child: Text("No ledger data available"))
          : _buildGroupedLedger(provider.ledger),
    );
  }

  /// 🧮 Group ledger items by Sale Order No
  Widget _buildGroupedLedger(List<Map<String, dynamic>> ledger) {
    // Group by saleOrderNo
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var entry in ledger) {
      final soNo = entry['saleOrderNo'] ?? 'Unknown';
      grouped.putIfAbsent(soNo, () => []).add(entry);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: grouped.entries.map((group) {
        final saleOrderNo = group.key;
        final items = group.value;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          shadowColor: Colors.black26,
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            backgroundColor: Colors.white,
            collapsedBackgroundColor: Colors.indigo.shade50,
            iconColor: Colors.indigo,
            collapsedIconColor: Colors.indigo,
            title: Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  "Sale Order No: ",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                Text(
                  saleOrderNo,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade100, Colors.indigo.shade50],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                child: _buildHeaderRow(),
              ),
              const Divider(height: 1, color: Colors.black26),
              Column(
                children: items.map((item) => _buildLedgerRow(item)).toList(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 🏷️ Header Row
  Widget _buildHeaderRow() {
    TextStyle headerStyle = const TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 13,
      color: Colors.black87,
    );

    return Row(
      children: [
        Expanded(flex: 2, child: Text("Order Date", style: headerStyle)),
        Expanded(flex: 2, child: Text("Delivery", style: headerStyle)),

        Expanded(flex: 2, child: Text("Credit", style: headerStyle)),
        Expanded(flex: 2, child: Text("Debit", style: headerStyle)),
        Expanded(flex: 2, child: Text("Balance", style: headerStyle)),
      ],
    );
  }

  /// 💰 Ledger Row (per item)
  Widget _buildLedgerRow(Map<String, dynamic> item) {
    String orderDate = 'N/A';
    String deliveryDate = 'N/A';
    try {
      if (item['orderDate'] != null &&
          item['orderDate'].toString().isNotEmpty) {
        orderDate = DateFormat(
          'dd-MM-yyyy',
        ).format(DateTime.parse(item['orderDate']));
      }

      if (item['deliveryDate'] != null &&
          item['deliveryDate'].toString().isNotEmpty) {
        // 🟢 Format delivery date as dd-MM-yyyy
        deliveryDate = DateFormat(
          'dd-MM-yyyy',
        ).format(DateTime.parse(item['deliveryDate']));
      }
    } catch (e) {
      debugPrint("Date parsing error: $e");
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              orderDate,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(flex: 2, child: Text(deliveryDate)),
          Expanded(
            flex: 2,
            child: Text(
              item['credit']?.toString() ?? '0',
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item['debit']?.toString() ?? '0',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item['balance']?.toString() ?? '0',
              style: const TextStyle(
                color: Colors.indigo,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
