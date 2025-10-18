import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:yenposapp/Global/globals_data.dart';
import 'package:yenposapp/Sale_order/Provider/bank_search_provider.dart';

class BankSearchDropdown extends StatefulWidget {
  final GlobalKey keyboardKey;

  const BankSearchDropdown({Key? key, required this.keyboardKey})
      : super(key: key);

  @override
  _BankSearchDropdownState createState() => _BankSearchDropdownState();
}

class _BankSearchDropdownState extends State<BankSearchDropdown> {
  @override
  void initState() {
    super.initState();

    final bankProvider =
        Provider.of<BankSearchProvider>(context, listen: false);

    // When focus lost, clear suggestions
    bankProvider.bankFocusNode.addListener(() {
      if (!bankProvider.bankFocusNode.hasFocus) {
        bankProvider.suggestions.clear();
        setState(() {});
      }
    });
  }

  void _handleTap() {
    final bankProvider =
        Provider.of<BankSearchProvider>(context, listen: false);

    ActiveField.activate(
      ctrl: bankProvider.bankNameController,
      node: bankProvider.bankFocusNode,
      numeric: false,
      onChanged: (value) {
        _onBankNameChanged(value);
      },
    );

    FocusScope.of(context).requestFocus(bankProvider.bankFocusNode);
  }

  void _onBankNameChanged(String value) {
    final provider = context.read<BankSearchProvider>();

    provider.fetchSuggestions(value.toLowerCase());
    setState(() {}); // refresh UI to show dropdown
  }

  void _onSuggestionSelected(
      Map<String, dynamic> suggestion, BankSearchProvider bankProvider) {
    bankProvider.updateBankName(suggestion['bankName'] ?? '');
    bankProvider.suggestions.clear();
    setState(() {});
    FocusScope.of(context).unfocus();
  }

  void _showAddBankDialog(BankSearchProvider bankProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.account_balance, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Add Bank',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: TextFormField(
            controller: bankProvider.bankNameController,
            inputFormatters: [
              LengthLimitingTextInputFormatter(24),
              FilteringTextInputFormatter.allow(RegExp(r'^[a-zA-Z ]*$')),
            ],
            decoration: InputDecoration(
              labelText: 'Bank Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () async {
                final bankName = bankProvider.bankNameController.text.trim();
                if (bankName.isNotEmpty) {
                  final response = await bankProvider.addBank(bankName);
                  if (response) {
                    bankProvider.bankNameController.text = bankName;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Bank "$bankName" added!'),
                        backgroundColor: Colors.green));
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Failed to add bank.'),
                        backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bankProvider = Provider.of<BankSearchProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: bankProvider.bankNameController,
          focusNode: bankProvider.bankFocusNode,
          readOnly: true, // disable system keyboard
          showCursor: true,
          onTap: _handleTap,
          inputFormatters: [
            LengthLimitingTextInputFormatter(24),
            FilteringTextInputFormatter.allow(RegExp(r'^[a-zA-Z ]*$')),
          ],
          decoration: InputDecoration(
            labelText: 'Bank Name',
            prefixIcon:
                Icon(Icons.account_balance, color: Colors.blue.shade600),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        // 🔹 Inline suggestions dropdown
        if (bankProvider.suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 5),
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade100.withOpacity(0.8),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: bankProvider.suggestions.length + 1,
              itemBuilder: (context, index) {
                if (index < bankProvider.suggestions.length) {
                  final suggestion = bankProvider.suggestions[index];
                  return ListTile(
                    title: Text(suggestion['bankName'] ?? 'Unknown Bank'),
                    onTap: () =>
                        _onSuggestionSelected(suggestion, bankProvider),
                  );
                } else {
                  return ListTile(
                    leading: const Icon(Icons.add, color: Colors.green),
                    title: const Text('Add Bank Name'),
                    onTap: () => _showAddBankDialog(bankProvider),
                  );
                }
              },
            ),
          ),
      ],
    );
  }
}
