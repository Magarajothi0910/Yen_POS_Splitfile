import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yenposapp/Global/customAll_keyboard.dart';
import 'package:yenposapp/screens/sales_order/globals.dart';

import 'package:yenposapp/screens/sales_order/screens/create_salesOrder.dart/bank_search_dropdown.dart';
import 'package:yenposapp/screens/sales_order/screens/create_salesOrder.dart/employee_selection.dart';

import '../screens/sales_order/sales_order_providers/customerScreen_provider.dart';
// import '../screens/sales_order/screens/create_salesOrder.dart/employee_selection.dart';
// import 'dynamic_search_dropdown.dart';

class AdvanceAmountDialog extends StatefulWidget {
  final double advanceAmount;
  final String salesOrderId;
  final String saleOrderNo;
  final GlobalKey keyboardKey;
  const AdvanceAmountDialog(
      {Key? key,
      required this.keyboardKey,
      required this.advanceAmount,
      required this.salesOrderId,
      required this.saleOrderNo})
      : super(key: key);

  @override
  _AdvanceAmountDialogState createState() => _AdvanceAmountDialogState();

  static Future<Map<String, dynamic>?> show(BuildContext context,
      {required double advanceAmount,
      required GlobalKey keyboardKey,
      required String salesOrderId,
      required String saleOrderNo}) {
    return showDialog<Map<String, dynamic>>(
      barrierDismissible: false,
      context: context,
      builder: (context) => AdvanceAmountDialog(
        advanceAmount: advanceAmount,
        salesOrderId: salesOrderId,
        saleOrderNo: saleOrderNo,
        keyboardKey: keyboardKey,
      ),
    );
  }
}

class _AdvanceAmountDialogState extends State<AdvanceAmountDialog> {
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _salesPersonController = TextEditingController();
  final TextEditingController _returnAmountController = TextEditingController();
  late final TextEditingController _amountController;
  final GlobalKey keyboardKey = GlobalKey();

  // Payment method controllers
  final TextEditingController chequeNumberController = TextEditingController();
  final TextEditingController chequeAmountController = TextEditingController();
  final TextEditingController chequeNameController = TextEditingController();
  final TextEditingController chequeBankController = TextEditingController();
  final TextEditingController chequeDateController = TextEditingController();

  String selectedPaymentMethod = 'Cash'; // Default payment method

  //focus nodes
  FocusNode chequeNumberFocus = FocusNode();
  FocusNode chequeAmountFocus = FocusNode();
  FocusNode chequeNameFocus = FocusNode();
  FocusNode remarkFocus = FocusNode();
  FocusNode returnAmountFocus = FocusNode();
  FocusNode salespersonFocus = FocusNode();

  final List<String> paymentMethods = [
    'Cash',
    'Card',
    'UPI',
    'Cheque',
    'Others'
  ];
  @override
  void initState() {
    super.initState();
    _amountController =
        TextEditingController(text: widget.advanceAmount.toString());

    // show advanceAmount in return amount field by default
    _returnAmountController.text = widget.advanceAmount.toString();

    // For cheque also keep same by default
    chequeAmountController.text = widget.advanceAmount.toString();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    _amountController.dispose();
    _salesPersonController.dispose();
    _returnAmountController.dispose();
    chequeNumberController.dispose();
    chequeAmountController.dispose();
    chequeNameController.dispose();
    chequeBankController.dispose();
    chequeDateController.dispose();
    super.dispose();
  }

  // Helper field builder
  Widget _buildFormField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = true,
    String? prefixText,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      showCursor: true,
      keyboardType: keyboardType,
      onTap: onTap,
      style: const TextStyle(fontSize: 15, color: Colors.black87),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.black87, fontSize: 14),
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixText: prefixText,
        prefixIcon: Icon(icon, color: Colors.grey.shade600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.blue, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  // Payment method option builder
  Widget _buildPaymentMethodOption(String method, IconData icon) {
    final bool isSelected = selectedPaymentMethod == method;
    return InkWell(
      onTap: () {
        setState(() {
          selectedPaymentMethod = method;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade700 : Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: isSelected ? Colors.blue.shade200 : Colors.grey.shade200,
              blurRadius: isSelected ? 10 : 5,
              spreadRadius: 1,
            )
          ],
          border: Border.all(
            color: isSelected ? Colors.blue.shade700 : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.blue.shade700,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              method,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.blue.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customerScreenProvider = Provider.of<CustomerScreenProvider>(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 700),
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 16.0),

                  // Payment method UI
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Method',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildPaymentMethodOption('Cash', Icons.payments),
                              const SizedBox(width: 10),
                              _buildPaymentMethodOption(
                                  'Card', Icons.credit_card),
                              const SizedBox(width: 10),
                              _buildPaymentMethodOption('UPI', Icons.qr_code),
                              const SizedBox(width: 10),
                              _buildPaymentMethodOption(
                                  'Cheque', Icons.account_balance),
                              const SizedBox(width: 10),
                              _buildPaymentMethodOption(
                                  'Others', Icons.more_horiz),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Conditional cheque details
                  if (selectedPaymentMethod == 'Cheque')
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(bottom: 20),
                      child: buildChequeDetails(),
                    ),

                  // 🔹 Conditional Rows
                  if (selectedPaymentMethod == 'Cheque') ...[
                    Row(
                      children: [
                        Expanded(child: EmployeeSearchDropdown()),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildFormField(
                            controller: _remarksController,
                            labelText: 'Remarks',
                            icon: Icons.comment,
                            hintText: 'Enter remarks or comments',
                            keyboardType: TextInputType.multiline,
                            onTap: () {
                              ActiveField.activate(
                                ctrl: _remarksController,
                                node: remarkFocus,
                                numeric: false,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildFormField(
                            controller: _returnAmountController,
                            labelText: 'Return Amount',
                            icon: Icons.monetization_on,
                            hintText: 'Enter return amount',
                            keyboardType: TextInputType.number,
                            prefixText: '₹ ',
                            onTap: () {
                              ActiveField.activate(
                                ctrl: _returnAmountController,
                                node: returnAmountFocus,
                                numeric: true,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(child: EmployeeSearchDropdown()),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildFormField(
                      controller: _remarksController,
                      labelText: 'Remarks',
                      icon: Icons.comment,
                      hintText: 'Enter remarks or comments',
                      keyboardType: TextInputType.multiline,
                      onTap: () {
                        ActiveField.activate(
                          ctrl: _remarksController,
                          node: remarkFocus,
                          numeric: false,
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Custom Keyboard widget
                  Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.85,
                      child: SizedBox(
                        height: 180,
                        child: ValueListenableBuilder<TextEditingController?>(
                          valueListenable: ActiveField.controller,
                          builder: (context, ctrl, _) {
                            return Column(
                              children: [
                                const SizedBox(height: 8),
                                Expanded(
                                  child: CustomKeyboardWidgetAll2(
                                    controller: ctrl ?? TextEditingController(),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(color: Colors.red.shade300),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.close,
                                color: Colors.red.shade500, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.red.shade500,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          print("🟦 Submit button pressed");

                          // Step 1: Validate remarks
                          if (_remarksController.text.isEmpty) {
                            print("⚠️ Remarks field is empty");
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Please fill the Remarks')),
                            );
                            return;
                          } else {
                            print(
                                "✅ Remarks filled: ${_remarksController.text}");
                          }

                          // Step 2: Build approval details
                          final approvalDetails = {
                            "approvalType": "Cancel Order",
                            "summary": "no",
                          };
                          print("📋 Approval Details: $approvalDetails");

                          Map<String, dynamic> payload = {
                            "status": "Waiting for approval",
                            "cancelOrderRemark": _remarksController.text,
                            "canceledPersonName":
                                customerScreenProvider.searchController.text ??
                                    "",
                            "saleOrderNo": widget.saleOrderNo,
                            "returnAmount": _returnAmountController.text ?? "0",
                            "canceledPaymentType":
                                selectedPaymentMethod ?? "Cash",
                            "cancelOrderDate": DateTime.now().toIso8601String(),
                            "approvalDetails": [approvalDetails]
                          };

                          print("🛠️ Payload created:");
                          payload.forEach((key, value) {
                            print("   ➡️ $key : $value");
                          });

                          // Step 4: Call Provider method
                          print(
                              "📡 Calling cancelOrder with SaleOrderNo: ${widget.saleOrderNo}");
                          customerScreenProvider.cancelOrder(
                              widget.saleOrderNo, payload);

                          // Step 5: Navigate back
                          print(
                              "🔙 Closing dialog and returning to previous screen");
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          shadowColor: Colors.blue.shade300,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.check_circle, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Submit',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildChequeDetails() {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: buildStyledFormField(
                  controller: chequeNumberController,
                  focusNode: chequeNumberFocus,
                  labelText: 'Cheque Number',
                  icon: Icons.numbers,
                  hintText: 'Enter cheque number',
                  keyboardType: TextInputType.number,
                  readOnly: true,
                  onTap: () {
                    ActiveField.activate(
                        ctrl: chequeNumberController,
                        numeric: false,
                        node: chequeNumberFocus);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: buildStyledFormField(
                  controller: chequeAmountController,
                  focusNode: chequeAmountFocus,
                  labelText: 'Cheque Amount',
                  icon: Icons.currency_rupee,
                  hintText: 'Enter amount',
                  keyboardType: TextInputType.number,
                  prefixText: '₹ ',
                  readOnly: true,
                  onTap: () {
                    ActiveField.activate(
                        ctrl: chequeAmountController,
                        numeric: true,
                        node: chequeAmountFocus);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: buildStyledFormField(
                  controller: chequeDateController,
                  labelText: 'Cheque Date',
                  icon: Icons.calendar_today,
                  hintText: 'Select date',
                  readOnly: true,
                  onTap: () async {
                    final DateTime now = DateTime.now();
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: now,
                      firstDate: DateTime(now.year, now.month,
                          now.day), // ⛔ disables past dates
                      lastDate: DateTime(2100),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Colors.blueAccent,
                              onPrimary: Colors.white,
                              onSurface: Colors.black,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      chequeDateController.text =
                          DateFormat('dd-MM-yyyy').format(picked);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: buildStyledFormField(
                  controller: chequeNameController,
                  focusNode: chequeNameFocus,
                  labelText: 'Cheque Holder Name',
                  icon: Icons.person,
                  hintText: 'Enter name on cheque',
                  readOnly: true,
                  onTap: () {
                    ActiveField.activate(
                        ctrl: chequeNameController,
                        numeric: false,
                        node: chequeNameFocus);
                  },
                ),
              ),
              const SizedBox(width: 15),
              Expanded(child: BankSearchDropdown(keyboardKey: keyboardKey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade800,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Cancel Order',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          Row(
            children: [
              const Icon(Icons.currency_rupee, color: Colors.white, size: 22),
              const SizedBox(width: 4),
              Text(
                _amountController.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildStyledFormField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    String? prefixText,
    bool readOnly = false,
    VoidCallback? onTap,
    FocusNode? focusNode,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      readOnly: readOnly,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15, color: Colors.black87),
      onTap: onTap,
      decoration: InputDecoration(
        prefixText: prefixText,
        labelText: labelText,
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon, color: Colors.grey.shade700),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.blue, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      ),
    );
  }
}
