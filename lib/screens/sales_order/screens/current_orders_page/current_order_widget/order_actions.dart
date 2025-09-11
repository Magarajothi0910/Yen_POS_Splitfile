import 'package:flutter/material.dart';
import '../../../../../Global/custom_button_reuse.dart';
import '../../../../../Global/custom_colors.dart';
import '../../../../../Global/custom_sized_box.dart';
import '../../../sales_order_print/currentOrderPrint.dart';
import '../../model/sales_order_model.dart';

class OrderActions extends StatelessWidget {
  final SalesOrderDisplay salesOrder;

  const OrderActions({super.key, required this.salesOrder});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomButton(
              text: 'Pay ₹ ${salesOrder.balanceAmount}',
              onPressed: salesOrder.status != "SalesOrder Completed"
                  ? () => _showPaymentDialog(context, salesOrder)
                  : () {},
              backgroundColor: salesOrder.status != "SalesOrder Completed"
                  ? CustomColors.primaryColor
                  : Colors.grey,
              textColor: CustomColors.whiteColor,
              padding:
                  const EdgeInsets.symmetric(horizontal: 100, vertical: 22),
            ),
          ],
        ),
      ],
    );
  }

  void _showPaymentDialog(BuildContext context, SalesOrderDisplay salesOrder) {
    final totalAmount = salesOrder.balanceAmount;

    if (totalAmount != 0) {
      showDialog(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.white,
            child: CustomSizedBox(
              width: MediaQuery.of(context).size.width * 0.5,
              child: OrderManagementPayandPrint(
                totalAmount: totalAmount,
                holdBillId: '',
                orderId: salesOrder.saleOrderNo,
                employee: salesOrder.employeeName,
                discount: salesOrder.discount,
                customerNumber: salesOrder.customerNumber,
                salesOrder: salesOrder,
              ),
            ),
          );
        },
      );
    }
  }
}
