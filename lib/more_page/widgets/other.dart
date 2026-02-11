// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:yen_pos/Global/Widget/custom_colors.dart';
// import 'package:yen_pos/Global/globals_data.dart';
// import 'package:yen_pos/invoice_pay_and_print_page.dart/provider/options_provider.dart';

// class OthersScreen extends StatefulWidget {
//   @override
//   State<OthersScreen> createState() => _OthersScreenState();
// }

// class _OthersScreenState extends State<OthersScreen> {
//   TextEditingController controller = TextEditingController();
//   String? selectedHelpText;
//   final ScrollController _scrollController = ScrollController();

//   @override
//   Widget build(BuildContext context) {
//     return Consumer<OptionsProvider>(
//       builder: (context, prov, _) {
//         return Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Center(
//               child: Text("System Settings", style: TextStyle(fontFamily: 'Poppins',fontSize: 25, fontWeight: FontWeight.w500)),
//             ),
//             Divider(indent: 10, endIndent: 10),
//             Expanded(
//               child: Row(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   /// LEFT SIDE SETTINGS PANEL — Scrollable
//                   Expanded(
//                     child: Scrollbar(
//                       controller: _scrollController,
//                       thumbVisibility: true,
//                       thickness: 8,
//                       radius: Radius.circular(10),
//                       child: SingleChildScrollView(
//                         controller: _scrollController,
//                         padding: const EdgeInsets.all(8.0),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             _buildSectionTitle("Internal Settings"),
//                             buildSettingsRow(
//                               title: "External KeyBoard",
//                               value: isKeyboardEnabled,
//                               Function: prov.toggleKeyboardButton,
//                             ),
//                             buildSettingsRow(title: "Add Item to Cart", value: isCartEnabled, Function: prov.toggleCartButton),
//                             _buildTicketInput(prov),
//                             _buildSectionTitle("Payment Settings"),
//                             buildSettingsRow(
//                               title: "POS Online Payment",
//                               value: isPaymentEnabled,
//                               Function: prov.togglePaymentButton,
//                             ),
//                              buildSettingsRow(
//                               title: "KOT Online Payment",
//                               value: isKOTPaymentEnabled,
//                               Function: () => prov.toggleKOTPaymentButton(context),
//                             ),
//                             buildSettingsRow(
//                               title: "SO Online Payment",
//                               value: isSOPaymentEnabled,
//                               Function:prov.toggleSOPaymentButton,
//                             ),
//                             _buildSectionTitle("Bill Settings"),
//                             _buildSectionSubTitle("Dine in"),
//                              buildSettingsRow(title: "KOT Overall Print", value: isKOTPrintEnabled, Function: prov.toggleKOTPrintButton),
//                               buildSettingsRow(title: "WhatsApp", value: isKOTWhatsappEnabled, Function: prov.toggleKOTWhatsappButton),
//                                buildSettingsRow(title: "KOT Payment Screen", value: isDineInEnabled, Function: prov.toggleKOTButton),
//                             _buildSectionSubTitle("Take Away"),
//                             buildSettingsRow(title: "Print", value: isPrintEnabled, Function: prov.togglePrintButton),
//                             buildSettingsRow(title: "WhatsApp", value: isWhatsAppEnabled, Function: prov.toggleWhatsAppButton),
//                             buildSettingsRow(title: "SMS", value: isSMSEnabled, Function: prov.toggleSMSButton),
//                             _buildSectionSubTitle("Sale Order"),
//                             buildSettingsRow(title: "Print", value: isSOPrintEnabled, Function: prov.toggleSOPrintButton),
//                             buildSettingsRow(title: "WhatsApp", value: isSOWhatsAppEnabled, Function: prov.toggleSOWhatsappTButton),
//                             buildSettingsRow(title: "SMS", value: isSOSMSEnabled, Function: prov.toggleSOSMSButton),
//                             _buildSectionTitle("GST Settings"),
//                             buildSettingsRow(title: "Remove GST in Print", value: isGSTEnabled, Function: prov.toggleGSTButton),
//                             SizedBox(height: 20),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),

//                   /// Divider
//                   Padding(
//                     padding: const EdgeInsets.all(8.0),
//                     child: Container(width: 1, color: Colors.grey),
//                   ),

//                   /// RIGHT SIDE HELP PANEL (Fixed)
//                   Expanded(
//                     flex: 2,
//                     child: Container(
//                       padding: EdgeInsets.all(16),
//                       child: selectedHelpText == null
//                           ? Center(
//                               child: Text(
//                                 "Click a help icon to view details here",
//                                 style: TextStyle(fontFamily: 'Poppins',fontSize: 16, color: Colors.grey),
//                                 textAlign: TextAlign.center,
//                               ),
//                             )
//                           : Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   "Description",
//                                   style: TextStyle(fontFamily: 'Poppins',fontSize: 20, fontWeight: FontWeight.bold, color: CustomColors.blueColor),
//                                 ),
//                                 SizedBox(height: 10),
//                                 SelectableText(
//                                   selectedHelpText!,
//                                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400, height: 1.5, fontFamily: "Poppins"),
//                                 ),
//                               ],
//                             ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   /// Section Title Widget
//   Widget _buildSectionTitle(String title) {
//     return Container(
//       width: double.infinity,
//       padding: EdgeInsets.all(5),
//       margin: EdgeInsets.only(bottom: 5, top: 10),
//       decoration: BoxDecoration(color: CustomColors.blueColor, borderRadius: BorderRadius.circular(3)),
//       child: Center(
//         child: Text(
//           title,
//           style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: CustomColors.whiteColor, fontFamily: "Poppins"),
//         ),
//       ),
//     );
//   }
//    Widget _buildSectionSubTitle(String title) {
//     return Container(
//       width: double.infinity,
//       padding: EdgeInsets.all(5),
//       margin: EdgeInsets.only(bottom: 5, top: 10),
//       decoration: BoxDecoration(color: CustomColors.blueColor.withOpacity(0.4), borderRadius: BorderRadius.circular(3)),
//       child: Center(
//         child: Text(
//           title,
//           style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: CustomColors.black.withOpacity(0.8), fontFamily: "Poppins"),
//         ),
//       ),
//     );
//   }

//   /// Ticket input row
//   Widget _buildTicketInput(OptionsProvider prov) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(
//               "Add Ticket Title",
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400, fontFamily: "Poppins"),
//             ),
//             IconButton(
//               onPressed: () {
//                 setState(() {
//                   selectedHelpText = getHelpText("Add Ticket Title");
//                 });
//               },
//               icon: Icon(Icons.help),
//             ),
//           ],
//         ),
//         SizedBox(height: 5),
//         Row(
//           children: [
//             Expanded(
//               child: SizedBox(
//                 height: 45,
//                 child: TextField(
//                   controller: controller,
//                   readOnly: !isTicketEnabled,
//                   cursorColor: CustomColors.blueColor,
//                   onSubmitted: (value) {
//                     ticketName = controller.text;
//                     debugPrint("Ticket Name - $ticketName");
//                   },
//                   decoration: InputDecoration(
//                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//                     enabledBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8),
//                       borderSide: BorderSide(color: CustomColors.blueColor),
//                     ),
//                     focusedBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8),
//                       borderSide: BorderSide(width: 2, color: CustomColors.blueColor),
//                     ),
//                     disabledBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8),
//                       borderSide: BorderSide(color: CustomColors.grey),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//             SizedBox(width: 6),
//             Switch(
//               value: isTicketEnabled,
//               onChanged: (value) {
//                 prov.toggleTicketButton();
//                 if (!value) {
//                   controller.clear();
//                   ticketName = '';
//                 }
//               },
//               activeColor: CustomColors.blueColor,
//               inactiveThumbColor: CustomColors.grey,
//               inactiveTrackColor: CustomColors.white70Color,
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   /// Common setting row builder
//   Widget buildSettingsRow({required String title, required value, required Function}) {
//     return Row(
//       children: [
//         Expanded(
//           child: Text(
//             title,
//             style: TextStyle(fontFamily: "Poppins", fontSize: 18, fontWeight: FontWeight.w400),
//           ),
//         ),
//         Switch(
//           value: value,
//           onChanged: (v) => Function(),
//           activeColor: CustomColors.blueColor,
//           inactiveThumbColor: CustomColors.grey,
//           inactiveTrackColor: CustomColors.white70Color,
//         ),
//         IconButton(
//           onPressed: () {
//             setState(() {
//               selectedHelpText = getHelpText(title);
//             });
//           },
//           icon: Icon(Icons.help),
//         ),
//       ],
//     );
//   }

//   /// Help text for each setting
//   String getHelpText(String title) {
//     switch (title) {
//       case "External KeyBoard":
//         return "⌨️ External Keyboard Integration\n\n"
//             "Purpose: Allows you to connect and use an external keyboard for faster data entry and navigation.\n\n"
//             "• When ON: External keyboard shortcuts and input will function throughout the billing interface, improving typing speed and reducing dependency on touch input.\n"
//             "• When OFF: Only the on-screen (virtual) keyboard will be available for text input.";

//       case "Add Item to Cart":
//         return "🛒 Automatic Cart Addition\n\n"
//             "Purpose: Streamlines the sales process by automatically adding scanned or selected items to the cart.\n\n"
//             "• When ON: Every scanned barcode or selected product is added instantly to the cart without needing manual confirmation — ideal for fast-moving billing counters.\n"
//             "• When OFF: Each item must be confirmed manually before being added, giving you more control but slightly slowing down checkout speed.";

//       case "Add Ticket Title":
//         return "🎫 Custom Ticket Title\n\n"
//             "Purpose: Helps you organize and categorize tickets or orders by adding custom titles or notes.\n\n"
//             "• When ON: Enables a text field where you can enter custom names or identifiers for tickets (e.g., 'Corporate Order', 'Online Pickup').\n"
//             "• When OFF: Ticket title input is disabled; all tickets will use the default system naming convention.";

//       case "Online Payment":
//         return "💳 Online Payment Enablement\n\n"
//             "Purpose: Activates the ability to record and manage digital payment modes within the billing system.\n\n"
//             "• When ON: Customers can pay through supported methods such as UPI, debit/credit cards, or mobile wallets. These transactions will be reflected in your sales reports accordingly.\n"
//             "• When OFF: Only cash transactions are allowed; online payment modes will not be displayed during checkout.";

//       case "Print":
//         return "🖨️ Automatic Invoice Printing\n\n"
//             "Purpose: Ensures that every completed sale is immediately followed by invoice printing for quick customer handover.\n\n"
//             "• When ON: The printer will automatically generate a physical copy of the invoice once payment is confirmed — best suited for retail environments.\n"
//             "• When OFF: The system will not print automatically. Invoices can still be printed manually from the sales history or invoice screen.";

//       case "Remove GST in Print":
//         return "💰 Display GST in Printed Invoice\n\n"
//             "Purpose: Controls whether tax details (GST) are shown or hidden on the printed customer invoice.\n\n"
//             "• When ON: GST values and breakdowns will be hidden from the printed invoice — useful when issuing simplified or non-tax invoices.\n"
//             "• When OFF: GST percentages and amounts will appear clearly on the printout, as per standard tax-compliant invoice format.";

//       case "WhatsApp":
//         return "📱 WhatsApp Invoice Sharing\n\n"
//             "Purpose: Enables automatic sharing of digital invoices or order confirmations via WhatsApp to customers.\n\n"
//             "• When ON: After billing, the system can automatically send the invoice or order link to the customer’s WhatsApp number — promoting eco-friendly, paperless transactions.\n"
//             "• When OFF: WhatsApp message sharing is disabled; invoices can only be printed or manually shared.";

//       case "SMS":
//         return "📩 SMS Notifications\n\n"
//             "Purpose: Sends automated SMS updates for transactions, promotions, or payment confirmations.\n\n"
//             "• When ON: The system will send SMS messages such as payment receipts, thank-you notes, or promotional alerts to registered customer numbers.\n"
//             "• When OFF: No SMS notifications will be sent. Communication will rely on printed or WhatsApp-based methods.";

//       default:
//         return "ℹ️ No description available for this setting.";
//     }
//   }
// }

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Global/Widget/custom_colors.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/invoice_pay_and_print_page.dart/provider/options_provider.dart';

class OthersScreen extends StatefulWidget {
  @override
  State<OthersScreen> createState() => _OthersScreenState();
}

class _OthersScreenState extends State<OthersScreen> {
  TextEditingController controller = TextEditingController();
  String? selectedHelpText;
  final ScrollController _scrollController = ScrollController();

  /// ✅ POS-style confirmation dialog
  Future<bool> _showConfirmDialog(String title, bool value) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: Colors.white,
              elevation: 8,
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              title: Text(
                "Confirm Action",
                style: TextStyle(
                  fontFamily: "Poppins",
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.blueGrey[900],
                ),
              ),
              content: Text(
                "Are you sure you want to ${value ? 'enable' : 'disable'} \"$title\"?",
                style: TextStyle(
                  fontFamily: "Poppins",
                  fontSize: 15,
                  height: 1.45,
                  color: Colors.blueGrey[700],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blueGrey[600],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(
                      fontFamily: "Poppins",
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  child: const Text("Cancel"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, // Material Blue
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: Colors.blue.withOpacity(0.4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: "Poppins",
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  child: const Text("Confirm"),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OptionsProvider>(
      builder: (context, prov, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                "System Settings",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 25,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Divider(indent: 10, endIndent: 10),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// LEFT PANEL
                  Expanded(
                    child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      thickness: 8,
                      radius: Radius.circular(10),
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle("Internal Settings"),
                            buildSettingsRow(
                              title: "External KeyBoard",
                              value: isKeyboardEnabled,
                              Function: prov.toggleKeyboardButton,
                            ),
                            buildSettingsRow(
                              title: "Add Item to Cart",
                              value: isCartEnabled,
                              Function: prov.toggleCartButton,
                            ),
                            _buildTicketInput(prov),
                            _buildSectionTitle("Payment Settings"),
                            buildSettingsRow(
                              title: "POS Online Payment",
                              value: isPaymentEnabled,
                              Function: prov.togglePaymentButton,
                            ),
                            buildSettingsRow(
                              title: "KOT Online Payment",
                              value: isKOTPaymentEnabled,
                              Function: () =>
                                  prov.toggleKOTPaymentButton(context),
                            ),
                            buildSettingsRow(
                              title: "SO Online Payment",
                              value: isSOPaymentEnabled,
                              Function: prov.toggleSOPaymentButton,
                            ),
                            _buildSectionTitle("Bill Settings"),
                            _buildSectionSubTitle("Dine in"),
                            buildSettingsRow(
                              title: "KOT Overall Print",
                              value: isKOTPrintEnabled,
                              Function: prov.toggleKOTPrintButton,
                            ),
                            buildSettingsRow(
                              title: "WhatsApp",
                              value: isKOTWhatsappEnabled,
                              Function: prov.toggleKOTWhatsappButton,
                            ),
                            ValueListenableBuilder<bool>(
                              valueListenable: isDineInEnabled,
                              builder: (context, value, child) {
                                return buildSettingsRow(
                                  title: "KOT Payment Screen",
                                  value: value, // ✅ use notifier value
                                  Function: prov.toggleKOTButton,
                                );
                              },
                            ),

                            _buildSectionSubTitle("Take Away"),
                            buildSettingsRow(
                              title: "Print",
                              value: isPrintEnabled,
                              Function: prov.togglePrintButton,
                            ),
                            buildSettingsRow(
                              title: "WhatsApp",
                              value: isWhatsAppEnabled,
                              Function: prov.toggleWhatsAppButton,
                            ),
                            buildSettingsRow(
                              title: "SMS",
                              value: isSMSEnabled,
                              Function: prov.toggleSMSButton,
                            ),
                            _buildSectionSubTitle("Sale Order"),
                            buildSettingsRow(
                              title: "Print",
                              value: isSOPrintEnabled,
                              Function: prov.toggleSOPrintButton,
                            ),
                            buildSettingsRow(
                              title: "WhatsApp",
                              value: isSOWhatsAppEnabled,
                              Function: prov.toggleSOWhatsappTButton,
                            ),
                            buildSettingsRow(
                              title: "SMS",
                              value: isSOSMSEnabled,
                              Function: prov.toggleSOSMSButton,
                            ),
                            _buildSectionTitle("GST Settings"),
                            buildSettingsRow(
                              title: "Remove GST in Print",
                              value: isGSTEnabled,
                              Function: prov.toggleGSTButton,
                            ),
                            SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),

                  /// DIVIDER
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(width: 1, color: Colors.grey),
                  ),

                  /// RIGHT HELP PANEL
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: EdgeInsets.all(16),
                      child: selectedHelpText == null
                          ? Center(
                              child: Text(
                                "Click a help icon to view details here",
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Description",
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: CustomColors.blueColor,
                                  ),
                                ),
                                SizedBox(height: 10),
                                SelectableText(
                                  selectedHelpText!,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w400,
                                    height: 1.5,
                                    fontFamily: "Poppins",
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// 🔒 POS-safe switch with confirmation
  Widget buildSettingsRow({
    required String title,
    required value,
    required Function,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: "Poppins",
              fontSize: 18,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: (v) async {
            final confirmed = await _showConfirmDialog(title, v);
            if (confirmed) {
              Function();
            }
          },
          activeColor: CustomColors.blueColor,
          inactiveThumbColor: CustomColors.grey,
          inactiveTrackColor: CustomColors.white70Color,
        ),
        IconButton(
          onPressed: () {
            setState(() {
              selectedHelpText = getHelpText(title);
            });
          },
          icon: Icon(Icons.help),
        ),
      ],
    );
  }

  /// Section Title
  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(5),
      margin: EdgeInsets.only(bottom: 5, top: 10),
      decoration: BoxDecoration(
        color: CustomColors.blueColor,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: CustomColors.whiteColor,
            fontFamily: "Poppins",
          ),
        ),
      ),
    );
  }

  Widget _buildSectionSubTitle(String title) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(5),
      margin: EdgeInsets.only(bottom: 5, top: 10),
      decoration: BoxDecoration(
        color: CustomColors.blueColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: CustomColors.black.withOpacity(0.8),
            fontFamily: "Poppins",
          ),
        ),
      ),
    );
  }

  /// Ticket input remains unchanged
  Widget _buildTicketInput(OptionsProvider prov) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Add Ticket Title",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                fontFamily: "Poppins",
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  selectedHelpText = getHelpText("Add Ticket Title");
                });
              },
              icon: Icon(Icons.help),
            ),
          ],
        ),
        SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 45,
                child: TextField(
                  controller: controller,
                  readOnly: !isTicketEnabled,
                  cursorColor: CustomColors.blueColor,
                  onSubmitted: (value) {
                    ticketName = controller.text;
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 6),
            Switch(
              value: isTicketEnabled,
              onChanged: (value) async {
                final confirmed = await _showConfirmDialog(
                  "Add Ticket Title",
                  value,
                );
                if (confirmed) {
                  prov.toggleTicketButton();
                  if (!value) {
                    controller.clear();
                    ticketName = '';
                  }
                }
              },
              activeColor: CustomColors.blueColor,
            ),
          ],
        ),
      ],
    );
  }

  /// Help text unchanged
  String getHelpText(String title) {
    return "ℹ️ No description available for this setting.";
  }
}
