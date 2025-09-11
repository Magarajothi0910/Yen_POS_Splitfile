

import 'package:flutter/material.dart';

import '../model/sales_order_model.dart';

class EditableCustomerDetails extends StatefulWidget {
  final SalesOrderDisplay salesOrder;
  final Function(Map<String, String>) onUpdate;

  const EditableCustomerDetails({
    super.key,
    required this.salesOrder,
    required this.onUpdate,
  });

  @override
  _EditableCustomerDetailsState createState() =>
      _EditableCustomerDetailsState();
}

class _EditableCustomerDetailsState extends State<EditableCustomerDetails> {
  bool _isEditing = false;
  late TextEditingController _nameController;
  late TextEditingController _mobileController;
  late TextEditingController _deliveryDateController;
  late TextEditingController _paymentTypeController;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _nameController =
        TextEditingController(text: widget.salesOrder.customerName);
    _mobileController =
        TextEditingController(text: widget.salesOrder.customerNumber);
    _deliveryDateController =
        TextEditingController(text: widget.salesOrder.deliveryDate);
    _paymentTypeController =
        TextEditingController(text: widget.salesOrder.paymentType);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _deliveryDateController.dispose();
    _paymentTypeController.dispose();
    super.dispose();
  }

  Widget _buildEditableField(String label, TextEditingController controller) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6), // Reduced vertical margin
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8), // Smaller radius
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 1), // Reduced offset for subtle shadow
          ),
        ],
      ),
      child: _isEditing
          ? TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(
                    color: Colors.blue[700],
                    fontSize: 12), // Smaller font size for label
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8), // Reduced padding
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.blue.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.blue.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: Colors.blue, width: 1.5), // Reduced border width
                ),
              ),
            )
          : ListTile(
              title: Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12, // Smaller font size
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                controller.text,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 14, // Slightly reduced font size for subtitle
                  fontWeight: FontWeight.w500,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 12, vertical: 4), // Reduced padding
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3, // Reduced elevation
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)), // Smaller radius
      child: Container(
        padding: EdgeInsets.all(16), // Reduced padding
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.blue.shade50],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Customer Details',
                  style: TextStyle(
                    fontSize: 16, // Reduced font size
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isEditing ? Icons.save_rounded : Icons.edit_rounded,
                    color: Colors.blue[700],
                    size: 20, // Reduced icon size
                  ),
                  onPressed: () {
                    if (_isEditing) {
                      widget.onUpdate({
                        'name': _nameController.text,
                        'mobile': _mobileController.text,
                        'deliveryDate': _deliveryDateController.text,
                        'paymentType': _paymentTypeController.text,
                      });
                    }
                    setState(() {
                      _isEditing = !_isEditing;
                    });
                  },
                ),
              ],
            ),
            Divider(color: Colors.blue[100], thickness: 1),
            SizedBox(height: 12), // Reduced space between sections
            _buildEditableField('Customer Name', _nameController),
            _buildEditableField('Mobile Number', _mobileController),
            _buildEditableField('Delivery Date', _deliveryDateController),
            _buildEditableField('Payment Type', _paymentTypeController),
          ],
        ),
      ),
    );
  }
}
