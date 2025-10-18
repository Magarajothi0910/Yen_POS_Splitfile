// lib/cash_management/cash_management_provider.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_notifier.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';

// Keep your globals (ensure these imports exist in your app)
import 'package:yenposapp/Global/globals_data.dart';
import 'package:yenposapp/shift_managment_page/openshift/open_shift.dart';

// External print services you already have
import '../screen/day_end_bill.dart';
import '../screen/dinomination_bill.dart';

class CashManagementProvider extends ChangeNotifier {
  /// ------------------ Notifiers (UI State) ------------------
  static final cashManagementView = ValueNotifier<String>('Shift Closing');

  static final isShiftClosed = ValueNotifier<bool>(false);
  static final isDayEndLoading = ValueNotifier<bool>(false);

  final ValueNotifier<String> currentDate = ValueNotifier("");
  final ValueNotifier<String> currentTime = ValueNotifier("");
  // Shift & Invoice data
  static final ValueNotifier<int> physicalCashSales = ValueNotifier<int>(0);
  static final ValueNotifier<int> manualOpeningBalance = ValueNotifier<int>(0);
  static final ValueNotifier<Map<int, int>> denominationCounts =
      ValueNotifier<Map<int, int>>({});
  //static final manualOpeningBalance = ValueNotifier<int>(0);
  static final cashTotal = ValueNotifier<int>(0);
  static final upiTotal = ValueNotifier<int>(0);
  static final cardTotal = ValueNotifier<int>(0);

  static ValueNotifier<String> cashSalesController = ValueNotifier("");
  static ValueNotifier<String> upiSalesController = ValueNotifier("");
  static ValueNotifier<String> cardSalesController = ValueNotifier("");

  static final totalInvoiceCash = ValueNotifier<double>(0);
  static final totalSalesOrderAdvanceCash = ValueNotifier<double>(0);
  static final totalSalesReturnCash = ValueNotifier<double>(0);
  static final systemCashTotal = ValueNotifier<double>(0);

  // final dayEndData = ValueNotifier<Map<String, dynamic>>({});

  // Manual text-field entries (as string to keep raw input)
  static final manualCashEntry = ValueNotifier<String>('');
  static final manualUpiEntry = ValueNotifier<String>('');
  static final manualCardEntry = ValueNotifier<String>('');

  /// Denominations: counts + derived total
  static const List<int> denominations = [500, 200, 100, 50, 20, 10, 5, 2, 1];
  // static final denominationCounts = ValueNotifier<Map<int, int>>({
  //   for (final d in denominations) d: 0,
  // });
  //static final physicalCashSales = ValueNotifier<int>(0);

  static const int actualOpeningCash = 3000;

  // system opening cash (initially 0, will be set to physical cash after shift is saved)
  final ValueNotifier<int> systemOpeningBalance = ValueNotifier(0);

  // shift status
  final ValueNotifier<bool> isShiftOpened = ValueNotifier(false);

  // Date/Time
  // final ValueNotifier<String> currentDate = ValueNotifier("");
  // final ValueNotifier<String> currentTime = ValueNotifier("");

  // denomination controllers & totals
  final Map<int, TextEditingController> _controllers = {
    500: TextEditingController(),
    200: TextEditingController(),
    100: TextEditingController(),
    50: TextEditingController(),
    20: TextEditingController(),
    10: TextEditingController(),
    5: TextEditingController(),
    2: TextEditingController(),
    1: TextEditingController(),
  };

  final ValueNotifier<Map<int, int>> denominationTotals =
      ValueNotifier<Map<int, int>>({});

  /// ------------------ Networking ------------------
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  @override
  void dispose() {
    // controllers.values.forEach((c) => c.dispose());
    // focusNodes.values.forEach((f) => f.dispose());
    super.dispose();
  }

  static String _formatDate(DateTime date) =>
      "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}";

  static String get _shiftQueryUrl =>
      "http://yenerp.com/fastapi/shifts/?shift_opening_date=${_formatDate(DateTime.now())}&branch_name=$branchName&device_number=$deviceNumber";

  static String get _invoiceTotalSalesUrl =>
      'http://192.168.29.78:8888/fastapi/invoices/?start_date=${_formatDate(DateTime.now())}&shift_number=1&branch_name=$branchName&device_number=$deviceNumber&show_totals=true';

  static String get _systemTotalsCashUrl =>
      'http://192.168.29.78:8888/fastapi/totals/systemtotalscash?date=${_formatDate(DateTime.now())}';

  /// ------------------ Lifecycle helpers ------------------
  static Future<void> bootstrap() async {
    await Future.wait([
      fetchShiftDetails(),
      fetchInvoiceData(),
      fetchSystemTotalsCash(),
      // fetchDayEndDetails(), // Removed: cannot call instance method from static context
    ]);
  }

  static void disposeAll() {
    // no-op here; if you create TextEditingControllers, dispose them here.
  }

  Future<void> fetchCurrentDateTime(context) async {
    final url = Uri.parse('https://yenerp.com/liveapi/datetime');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      currentDate.value = data["current_date"];
      currentTime.value = data["current_time"];
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to fetch date and time.')),
        );
      }
    }
    notifyListeners();
  }

  static Future<void> fetchInvoiceData() async {
    try {
      final res = await http.get(Uri.parse(_invoiceTotalSalesUrl));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        cashTotal.value = data['total_cash'] ?? 0;
        upiTotal.value = data['total_upi'] ?? 0;
        cardTotal.value = data['total_card'] ?? 0;
      }
    } catch (_) {}
  }

  static Future<void> fetchSystemTotalsCash() async {
    try {
      final res = await http.get(Uri.parse(_systemTotalsCashUrl));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        totalInvoiceCash.value = (data['totalInvoiceCash'] ?? 0).toDouble();
        totalSalesOrderAdvanceCash.value =
            (data['totalSalesOrderAdvanceCash'] ?? 0).toDouble();
        totalSalesReturnCash.value =
            (data['totalSalesReturnCash'] ?? 0).toDouble();
        systemCashTotal.value = (data['SystemCashTotal'] ?? 0).toDouble();
      }
    } catch (_) {}
  }

  /// Fetch shift details from API

  static Future<List<Map<String, String>>> fetchShiftDetails() async {
    //const String apiUrl = "http://yenerp.com/fastapi/shifts/";
    final String apiUrl =
        "https://yenerp.com/fastapi/shifts/all?branchName=$branchName";
    //const String apiUrl = "http://192.168.29.8:8888/shift/all/?branchName=$branchName";
    try {
      final response = await _dio.get(apiUrl);
      if (response.statusCode == 200) {
        List<dynamic> shifts = response.data is String
            ? json.decode(response.data)
            : response.data;

        if (shifts.isEmpty) return [];

        List<Map<String, String>> formattedShifts =
            (shifts as List<dynamic>).map<Map<String, String>>((
          shift,
        ) {
          shiftId.value = shift['shiftId']?.toString() ?? "";
          dayEndStatus.value = shift['dayEndStatus']?.toString() ?? "";
          status.value = shift['status']?.toString() ?? "";

          return {
            "shiftId": shift['shiftId']?.toString() ?? "",
            "shiftNumber": shift['shiftNumber']?.toString() ?? "",
            "OpeningDateTime": shift['OpeningDateTime']?.toString() ?? "",
            "ClosingDateTime": shift['ClosingDateTime']?.toString() ?? "",
            "systemOpeningBalance":
                shift['systemOpeningBalance']?.toString() ?? "0",
            "manualOpeningBalance":
                shift['manualOpeningBalance']?.toString() ?? "0",
            "systemClosingBalance":
                shift['systemClosingBalance']?.toString() ?? "0",
            "manualClosingBalance":
                shift['manualClosingBalance']?.toString() ?? "0",
            "openingDifferenceAmount":
                shift['openingDifferenceAmount']?.toString() ?? "0",
            "openingDifferenceType":
                shift['openingDifferenceType']?.toString() ?? "",
            "closingDifferenceAmount":
                shift['closingDifferenceAmount']?.toString() ?? "0",
            "closingDifferenceType":
                shift['closingDifferenceType']?.toString() ?? "",
            "systemCashSales": shift['systemCashSales']?.toString() ?? "0",
            "manualCashsales": shift['manualCashsales']?.toString() ?? "0",
            "kotCashSales": shift['kotCashSales']?.toString() ?? "0",
            "takeAwayCashSales": shift['takeAwayCashSales']?.toString() ?? "0",
            "saleOrderCashSales":
                shift['saleOrderCashSales']?.toString() ?? "0",
            "bdCakeCashSales": shift['bdCakeCashSales']?.toString() ?? "0",
            "cashSaleDifferenceAmount":
                shift['cashSaleDifferenceAmount']?.toString() ?? "0",
            "cashSaleDifferenceType":
                shift['cashSaleDifferenceType']?.toString() ?? "",
            "systemCardSales": shift['systemCardSales']?.toString() ?? "0",
            "manualCardsales": shift['manualCardsales']?.toString() ?? "0",
            "kotCardSales": shift['kotCardSales']?.toString() ?? "0",
            "takeAwayCardSales": shift['takeAwayCardSales']?.toString() ?? "0",
            "saleOrderCardSales":
                shift['saleOrderCardSales']?.toString() ?? "0",
            "bdCakeCardSales": shift['bdCakeCardSales']?.toString() ?? "0",
            "cardSaleDifferenceAmount":
                shift['cardSaleDifferenceAmount']?.toString() ?? "0",
            "cardSaleDifferenceType":
                shift['cardSaleDifferenceType']?.toString() ?? "",
            "systemUpiSales": shift['systemUpiSales']?.toString() ?? "0",
            "manualUpisales": shift['manualUpisales']?.toString() ?? "0",
            "kotUpiSales": shift['kotUpiSales']?.toString() ?? "0",
            "takeAwayUpiSales": shift['takeAwayUpiSales']?.toString() ?? "0",
            "saleOrderUpiSales": shift['saleOrderUpiSales']?.toString() ?? "0",
            "bdCakeUpiSales": shift['bdCakeUpiSales']?.toString() ?? "0",
            "upiSaleDifferenceAmount":
                shift['upiSaleDifferenceAmount']?.toString() ?? "0",
            "upiSaleDifferenceType":
                shift['upiSaleDifferenceType']?.toString() ?? "",
            "deliveryPartnerSales":
                shift['deliveryPartnerSales']?.toString() ?? "0",
            "otherSystemSales": shift['otherSystemSales']?.toString() ?? "0",
            "otherManualsales": shift['otherManualsales']?.toString() ?? "0",
            "totalKotSales": shift['totalKotSales']?.toString() ?? "0",
            "totalTakeAwaySales":
                shift['totalTakeAwaySales']?.toString() ?? "0",
            "totalSaleOrderSales":
                shift['totalSaleOrderSales']?.toString() ?? "0",
            "totalBdCakeSales": shift['totalBdCakeSales']?.toString() ?? "0",
            "otherSaleDifferenceAmount":
                shift['otherSaleDifferenceAmount']?.toString() ?? "0",
            "otherSaleDifferenceType":
                shift['otherSaleDifferenceType']?.toString() ?? "",
            "totalSystemSales": shift['totalSystemSales']?.toString() ?? "0",
            "totalManualSales": shift['totalManualSales']?.toString() ?? "0",
            "kotOtherSales": shift['kotOtherSales']?.toString() ?? "0",
            "takeAwayOtherSales":
                shift['takeAwayOtherSales']?.toString() ?? "0",
            "saleOrderOtherSales":
                shift['saleOrderOtherSales']?.toString() ?? "0",
            "bdCakeOtherSales": shift['bdCakeOtherSales']?.toString() ?? "0",
            "totalDifferenceAmount":
                shift['totalDifferenceAmount']?.toString() ?? "0",
            "totalDifferenceType":
                shift['totalDifferenceType']?.toString() ?? "",
            "salesReturn": shift['salesReturn']?.toString() ?? "0",
            "dayEndStatus": shift['dayEndStatus']?.toString() ?? "",
            "status": shift['status']?.toString() ?? "",
            "branchId": shift['branchId']?.toString() ?? "",
            "branchName": shift['branchName']?.toString() ?? "",
            "empId": shift['empId']?.toString() ?? "",
            "empName": shift['empName']?.toString() ?? "",
            "deviceId": shift['deviceId']?.toString() ?? "",
            "deviceNumber": shift['deviceNumber']?.toString() ?? "",
          };
        }).toList();

        return formattedShifts;
      }
    } catch (e, st) {
    
    }
    return [];
  }

  /// Fetch day-end details from API

  Future<List<Map<String, String>>> fetchDayEndDetails() async {
    const String apiUrl = "https://yenerp.com/fastapi/dayends/";
    //const String apiUrl = "http://192.168.29.8:8888/dayEnd/";

    try {
      final response = await _dio.get(apiUrl);

      if (response.statusCode == 200 && response.data is List) {
        final List<dynamic> items = response.data as List<dynamic>;

        final formatted = items.map<Map<String, String>>((jsonItem) {
          final item = jsonItem as Map<String, dynamic>;

          return {
            'dayEndId': item['dayEndId']?.toString() ?? '',
            'dayOpeningDate': item['dayOpeningDate']?.toString() ?? '',
            'dayOpeningTime': item['dayOpeningTime']?.toString() ?? '',
            'dayClosingDate': item['dayClosingDate']?.toString() ?? '',
            'dayClosingTime': item['dayClosingTime']?.toString() ?? '',
            'systemCashSales': item['systemCashSales']?.toString() ?? '0',
            'manualCashSales': item['manualCashSales']?.toString() ?? '0',
            "kotCashSales": item['kotCashSales']?.toString() ?? "0",
            "takeAwayCashSales": item['takeAwayCashSales']?.toString() ?? "0",
            "saleOrderCashSales": item['saleOrderCashSales']?.toString() ?? "0",
            "bdCakeCashSales": item['bdCakeCashSales']?.toString() ?? "0",
            'cashDifferenceAmount':
                item['cashDifferenceAmount']?.toString() ?? '0',
            'cashDifferenceType': item['cashDifferenceType']?.toString() ?? '',
            'systemCardSales': item['systemCardSales']?.toString() ?? '0',
            'manualCardSales': item['manualCardSales']?.toString() ?? '0',
            "kotCardSales": item['kotCardSales']?.toString() ?? "0",
            "takeAwayCardSales": item['takeAwayCardSales']?.toString() ?? "0",
            "saleOrderCardSales": item['saleOrderCardSales']?.toString() ?? "0",
            "bdCakeCardSales": item['bdCakeCardSales']?.toString() ?? "0",
            'cardDifferenceAmount':
                item['cardDifferenceAmount']?.toString() ?? '0',
            'cardDifferenceType': item['cardDifferenceType']?.toString() ?? '',
            'systemUpiSales': item['systemUpiSales']?.toString() ?? '0',
            'manualUpiSales': item['manualUpiSales']?.toString() ?? '0',
            "kotUpiSales": item['kotUpiSales']?.toString() ?? "0",
            "takeAwayUpiSales": item['takeAwayUpiSales']?.toString() ?? "0",
            "saleOrderUpiSales": item['saleOrderUpiSales']?.toString() ?? "0",
            "bdCakeUpiSales": item['bdCakeUpiSales']?.toString() ?? "0",
            'upiDifferenceAmount':
                item['upiDifferenceAmount']?.toString() ?? '0',
            'upiDifferenceType': item['upiDifferenceType']?.toString() ?? '',
            'totalSystemSales': item['totalSystemSales']?.toString() ?? '0',
            'totalManualSales': item['totalManualSales']?.toString() ?? '0',
            "totalKotSales": item['totalKotSales']?.toString() ?? "0",
            "totalTakeAwaySales": item['totalTakeAwaySales']?.toString() ?? "0",
            "totalSaleOrderSales":
                item['totalSaleOrderSales']?.toString() ?? "0",
            "totalBdCakeSales": item['totalBdCakeSales']?.toString() ?? "0",
            'totalDifferenceAmount':
                item['totalDifferenceAmount']?.toString() ?? '0',
            'totalDifferenceType':
                item['totalDifferenceType']?.toString() ?? '',
            'systemDeliveryPartnerSales':
                item['systemDeliveryPartnerSales']?.toString() ?? '0',
            'manualDeliverypartnerSales':
                item['manualDeliverypartnerSales']?.toString() ?? '0',
            'systemOtherSales': item['systemOtherSales']?.toString() ?? '0',
            'manualOtherSales': item['manualOtherSales']?.toString() ?? '0',
            'salesReturn': item['salesReturn']?.toString() ?? '0',
            'status': item['status']?.toString() ?? '',
            'branchId': item['branchId']?.toString() ?? '',
            'branchName': item['branchName']?.toString() ?? '',
            'deviceId': item['deviceId']?.toString() ?? '',
            'deviceNumber': item['deviceNumber']?.toString() ?? '',
          };
        }).toList();

        dayEndData = formatted;
       
        return formatted;
      } else {
     
        return [];
      }
    } on DioError catch (e) {
      final errorMsg = e.response != null
          ? 'DioError: HTTP ${e.response?.statusCode}, data: ${e.response?.data}'
          : 'DioError: ${e.message}';
    
      return [];
    } catch (e, st) {
     
      return [];
    }
  }

  /// Print day-end report for open shifts

  Future<void> printOpenDayEndShifts(
    Map<String, dynamic> dayEnd,
    List<Map<String, dynamic>> shifts,
  ) async {
   

    CapabilityProfile profile;
    NetworkPrinter printer;
    Generator generator;

    // Initialize printer and generator
    try {
      profile = await CapabilityProfile.load();
      printer = NetworkPrinter(PaperSize.mm80, profile);
      generator = Generator(PaperSize.mm80, profile);
     
    } catch (e, st) {
    
      return;
    }

    // Connect to printer
    PosPrintResult res;
    try {
      res = await printer.connect("192.168.1.87", port: 9100);
   
      if (res != PosPrintResult.success) {
    
        return;
      }
    } catch (e, st) {
    
      return;
    }

    List<int> allBytes = [];
    DateFormat dateFormat = DateFormat('dd-MM-yy');
    DateFormat timeFormat = DateFormat('h:mm a');

    // Add main header for the receipt
    allBytes += generator.text(
      'Day End Report',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    );
    allBytes += generator.text(
      'BestMummy\nSweets & Cakes',
      styles: const PosStyles(align: PosAlign.center),
    );
    allBytes += generator.row([
      PosColumn(
        width: 6,
        text:
            "Date: ${DateFormat('dd-MM-yyyy').format(DateTime.now().toLocal())}",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text: "Time: ${DateFormat('HH:mm').format(DateTime.now())}",
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    allBytes += generator.feed(1);
    allBytes += generator.hr();

    // Day-End Details
    allBytes += generator.text(
      'Day End Details',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size1,
        width: PosTextSize.size1,
      ),
    );
    allBytes += generator.hr();

    // allBytes += generator.text("Day End ID: ${dayEnd['dayEndId'] ?? 'N/A'}");
    allBytes += generator.row([
      PosColumn(
        width: 6,
        text: "Opening Date: ${dayEnd['dayOpeningDate'] ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text: "Opening Time: ${dayEnd['dayOpeningTime'] ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    allBytes += generator.row([
      PosColumn(
        width: 6,
        text: "Closing Date: ${dayEnd['dayClosingDate'] ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text: "Closing Time: ${dayEnd['dayClosingTime'] ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    allBytes += generator.text("Branch Name: ${dayEnd['branchName'] ?? 'N/A'}");
    allBytes += generator.text("Branch ID: ${dayEnd['branchId'] ?? 'N/A'}");
    allBytes += generator.text("Device ID: ${dayEnd['deviceId'] ?? 'N/A'}");
    allBytes += generator.text(
      "Device Number: ${dayEnd['deviceNumber'] ?? 'N/A'}",
    );
    allBytes += generator.text("Status: ${dayEnd['status'] ?? 'N/A'}");

    allBytes += generator.hr();
    allBytes += generator.text(
      "OverAll Sales",
      styles: const PosStyles(bold: true, align: PosAlign.center),
    );
    allBytes += generator.hr();
    allBytes += generator.row([
      PosColumn(
        width: 6,
        text: "System: ${dayEnd['totalSystemSales']?.toString() ?? '0'}",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text: "Manual: ${dayEnd['totalManualSales']?.toString() ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    allBytes += generator.row([
      PosColumn(
        width: 6,
        text: "TakeAway: ${dayEnd['totalTakeAwaySales']?.toString() ?? '0'}",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text:
            "SaleOrder: ${dayEnd['totalSaleOrderSales']?.toString() ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    allBytes += generator.row([
      PosColumn(
        width: 6,
        text: "KOT: ${dayEnd['totalKotSales']?.toString() ?? '0'}",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text: "BDCake: ${dayEnd['totalBdCakeSales']?.toString() ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    allBytes += generator.row([
      PosColumn(
        width: 6,
        text:
            "Difference: ${dayEnd['totalDifferenceAmount']?.toString() ?? '0'}",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text: "Type: ${dayEnd['totalDifferenceType']?.toString() ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    allBytes += generator.hr();
    allBytes += generator.text(
      "Cash Sales",
      styles: const PosStyles(bold: true, align: PosAlign.center),
    );
    allBytes += generator.hr();
    allBytes += generator.row([
      PosColumn(
        width: 6,
        text: "System: ${dayEnd['systemCashSales']?.toString() ?? '0'}",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text: "Manual: ${dayEnd['manualCashSales']?.toString() ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    allBytes += generator.row([
      PosColumn(
        width: 6,
        text: "TakeAway: ${dayEnd['takeAwayCashSales']?.toString() ?? '0'}",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text: "SaleOrder: ${dayEnd['saleOrderCashSales']?.toString() ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    allBytes += generator.row([
      PosColumn(
        width: 6,
        text: "KOT: ${dayEnd['kotCashSales']?.toString() ?? '0'}",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text: "BDCake: ${dayEnd['bdCakeCashSales']?.toString() ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    allBytes += generator.row([
      PosColumn(
        width: 6,
        text:
            "Difference: ${dayEnd['cashDifferenceAmount']?.toString() ?? '0'}",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text: "Type: ${dayEnd['cashDifferenceType']?.toString() ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    allBytes += generator.hr();
    allBytes += generator.text(
      "Card Sales",
      styles: const PosStyles(bold: true, align: PosAlign.center),
    );
    allBytes += generator.hr();
    allBytes += generator.row([
      PosColumn(
        width: 6,
        text: "System: ${dayEnd['systemCardSales']?.toString() ?? '0'}",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text: "Manual: ${dayEnd['manualCardSales']?.toString() ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    allBytes += generator.row([
      PosColumn(
        width: 6,
        text: "TakeAway: ${dayEnd['takeAwayCardSales']?.toString() ?? '0'}",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text: "SaleOrder: ${dayEnd['saleOrderCardSales']?.toString() ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    allBytes += generator.row([
      PosColumn(
        width: 6,
        text: "KOT: ${dayEnd['kotCardSales']?.toString() ?? '0'}",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text: "BDCake: ${dayEnd['bdCakeCardSales']?.toString() ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    allBytes += generator.row([
      PosColumn(
        width: 6,
        text:
            "Difference: ${dayEnd['cardDifferenceAmount']?.toString() ?? '0'}",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text: "Type: ${dayEnd['cardDifferenceType']?.toString() ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    allBytes += generator.hr();
    allBytes += generator.text(
      "UPI Sales",
      styles: const PosStyles(bold: true, align: PosAlign.center),
    );
    allBytes += generator.hr();
    allBytes += generator.row([
      PosColumn(
        width: 6,
        text: "System: ${dayEnd['systemUpiSales']?.toString() ?? '0'}",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text: "Manual: ${dayEnd['manualUpiSales']?.toString() ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    allBytes += generator.row([
      PosColumn(
        width: 6,
        text: "TakeAway: ${dayEnd['takeAwayUpiSales']?.toString() ?? '0'}",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text: "SaleOrder: ${dayEnd['saleOrderUpiSales']?.toString() ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    allBytes += generator.row([
      PosColumn(
        width: 6,
        text: "KOT: ${dayEnd['kotUpiSales']?.toString() ?? '0'}",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text: "BDCake: ${dayEnd['bdCakeUpiSales']?.toString() ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    allBytes += generator.row([
      PosColumn(
        width: 6,
        text: "Difference: ${dayEnd['upiDifferenceAmount']?.toString() ?? '0'}",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text: "Type: ${dayEnd['upiDifferenceType']?.toString() ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    allBytes += generator.hr();

    allBytes += generator.text(
      "Delivery Partner Sales: ${dayEnd['systemDeliveryPartnerSales']?.toString() ?? 'N/A'}",
    );
    allBytes += generator.hr();
    allBytes += generator.text(
      "Other Sales: ${dayEnd['otherSales']?.toString() ?? 'N/A'}",
    );
    allBytes += generator.hr();
    allBytes += generator.text(
      "Sales Return: ${dayEnd['salesReturn']?.toString() ?? 'N/A'}",
    );

    allBytes += generator.feed(1);
    allBytes += generator.hr(ch: '=', linesAfter: 1);

    // Shift Details (only for dayEndStatus == "open")
    int openShiftCount = 0;
    for (var shift in shifts) {
      if (shift['dayEndStatus'] != 'open') {
     
        continue;
      }
      openShiftCount++;
     

      DateTime? openDt, closeDt;
      String openDate = "N/A",
          openTime = "N/A",
          closeDate = "N/A",
          closeTime = "N/A";

      try {
        if (shift['OpeningDateTime'] != null) {
          openDt = DateTime.parse(shift['OpeningDateTime']).toLocal();
          openDate = dateFormat.format(openDt);
          openTime = timeFormat.format(openDt);
        }
        if (shift['ClosingDateTime'] != null) {
          closeDt = DateTime.parse(shift['ClosingDateTime']).toLocal();
          closeDate = dateFormat.format(closeDt);
          closeTime = timeFormat.format(closeDt);
        }
       
      } catch (e, st) {
       
      }

      // Add shift header
      allBytes += generator.text(
        'Shift ${shift['shiftNumber'] ?? 'N/A'}',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      );
      allBytes += generator.hr();

      // Shift details
      allBytes += generator.row([
        PosColumn(
          width: 6,
          text: "Branch: ${shift['branchName'] ?? 'N/A'}",
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          width: 6,
          text: "Emp ID: ${shift['empId'] ?? 'N/A'}",
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      allBytes += generator.text("Emp Name: ${shift['empName'] ?? 'N/A'}");
      allBytes += generator.row([
        PosColumn(
          width: 6,
          text: "Opening Date: $openDate",
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          width: 6,
          text: "Opening Time: $openTime",
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      allBytes += generator.row([
        PosColumn(
          width: 6,
          text: "Closing Date: $closeDate",
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          width: 6,
          text: "Closing Time: $closeTime",
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      allBytes += generator.hr();

      // Overall Sales
      allBytes += generator.text(
        "OverAll Sales",
        styles: PosStyles(bold: true, align: PosAlign.center),
      );
      allBytes += generator.hr();
      allBytes += generator.row([
        PosColumn(
          width: 6,
          text: "System : ${shift['totalSystemSales'] ?? 'N/A'}",
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          width: 6,
          text: 'Manual : ${shift['totalManualSales'] ?? 'N/A'}',
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      allBytes += generator.row([
        PosColumn(
          width: 6,
          text: "TakeAway: ${shift['totalTakeAwaySales'] ?? 'N/A'}",
          styles: const PosStyles(align: PosAlign.left, bold: true),
        ),
        PosColumn(
          width: 6,
          text: 'SaleOrder: ${shift['totalSaleOrderSales'] ?? 'N/A'}',
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);
      allBytes += generator.row([
        PosColumn(
          width: 6,
          text: "KOT: ${shift['totalKotSales'] ?? 'N/A'}",
          styles: const PosStyles(align: PosAlign.left, bold: true),
        ),
        PosColumn(
          width: 6,
          text: 'BDCake: ${shift['totalBdCakeSales'] ?? 'N/A'}',
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);
      allBytes += generator.row([
        PosColumn(
          width: 6,
          text: "Difference: ${shift['totalDifferenceAmount'] ?? 'N/A'}",
          styles: const PosStyles(align: PosAlign.left, bold: true),
        ),
        PosColumn(
          width: 6,
          text: 'Type: ${shift['totalDifferenceType'] ?? 'N/A'}',
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);

      allBytes += generator.feed(1);
      allBytes += generator.hr(ch: '=', linesAfter: 1);
    }

    // Add footer and cut command
    allBytes += generator.text(
      "Generated at: ${dateFormat.format(DateTime.now())} ${timeFormat.format(DateTime.now())}",
      styles: const PosStyles(align: PosAlign.center),
    );
    allBytes += generator.feed(2);
    allBytes += generator.cut();

    // Send print data
    if (openShiftCount > 0 || allBytes.isNotEmpty) {
      try {
        printer.rawBytes(Uint8List.fromList(allBytes));
        debugPrint(
          "✅ Printed day-end details and $openShiftCount open shifts in a single receipt.",
        );
      } catch (e, st) {
      
      }
    } else {
      
    }

    // Disconnect printer
    try {
      printer.disconnect();
    
    } catch (e, st) {
    
    }
  }

  static Future<void> patchShiftClosingData(
    //final closingDifference = actualOpeningCash - manualOpeningBalance;
    String shiftID,
    BuildContext context,
  ) async {
    if (shiftID.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text('Shift ID is empty. Cannot close shift.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final patchUrl = "https://yenerp.com/fastapi/shifts/close-shift/$shiftID";
    //final patchUrl = "http://192.168.29.8:8888/shift/close-shift/$shiftID";
  
    try {
      // Convert denomination_counts keys to strings for JSON serialization
      final stringDenominationCounts = <String, int>{};
      denominationCounts.value.forEach((key, value) {
        stringDenominationCounts[key.toString()] = value;
      });
      final closingDifferenceAmount =
          (manualOpeningBalance.value - actualOpeningCash).toStringAsFixed(2);
      final closingDifferenceAmountNum =
          double.tryParse(closingDifferenceAmount) ?? 0.0;
      final closingDifferenceType = closingDifferenceAmountNum > 0
          ? "excess"
          : (closingDifferenceAmountNum < 0 ? "shortage" : "no difference");
      final payload = {
        "status": "closed",
        "manualCashsales": physicalCashSales.value,
        "manualUpisales": double.tryParse(upiSalesController.value) ?? 0.0,
        "manualCardsales": double.tryParse(cardSalesController.value) ?? 0.0,
        "manualClosingBalance": manualOpeningBalance.value.toString(),
        "closingDifferenceAmount": closingDifferenceAmount,
        "closingDifferenceType": closingDifferenceType,
      };

      final response = await _dio.patch(patchUrl, data: payload);

      if (response.statusCode == 200) {
        isShiftClosed.value = true;
        DenominationBill.printDenominationBill(context);

        // Fetch updated shift data
        final shifts = await fetchShiftDetails();
       
        final currentShift = shifts.firstWhere(
          (s) => s['shiftId'] == shiftID,
          orElse: () => {},
        );


        if (currentShift.isNotEmpty) {
          // Console output for debugging
          StringBuffer buffer = StringBuffer();
          buffer.writeln('=== Shift End Report ===');
          buffer.writeln('-----------------------');
          currentShift.forEach((key, value) {
            buffer.writeln('$key: $value');
          });
          buffer.writeln('-----------------------');
          debugPrint(buffer.toString());

          // Print to thermal printer
          await printShiftData(currentShift);
        }
   

        // Clear all fields after successful shift close
        physicalCashSales.value = 0;
        manualOpeningBalance.value = 0;
        denominationCounts.value = {};
        cashSalesController.value = "";
        upiSalesController.value = "";
        cardSalesController.value = "";
        ActiveField.controller.value?.clear();
        ActiveField.controller.value = null;

        // Show a snackbar to confirm
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Shift Closed & Report Printed')),
          );
        }

        // Navigate to OpenShift screen
        if (context.mounted) {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (context) => OpenShift()));
        }
      } else {
        // Handle non-200 status codes
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text(
                'Failed to close shift: Server returned status ${response.statusCode}',
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // Handle DioException and other errors
      String errorMessage = 'Failed to close shift: $e';
      if (e is DioException && e.response != null) {
        errorMessage =
            'Failed to close shift: ${e.response?.statusCode} - ${e.response?.data.toString() ?? e.message}';
    
      } else {

      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Print shift report to thermal printer

  static Future<void> printShiftData(Map<String, dynamic> shift) async {
    
    CapabilityProfile profile;
    NetworkPrinter printer;
    Generator generator;

    try {
      profile = await CapabilityProfile.load();
      printer = NetworkPrinter(PaperSize.mm80, profile);
      generator = Generator(PaperSize.mm80, profile);
     
    } catch (e, st) {
      debugPrint(
        "❌ Error loading profile or setting up printer/generator: $e\n$st",
      );
      return;
    }

    PosPrintResult res;
    try {
      res = await printer.connect("192.168.1.87", port: 9100);
     
      if (res != PosPrintResult.success) {
       
        return;
      }
    } catch (e, st) {
     
      return;
    }

    DateFormat dateFormat = DateFormat('dd-MM-yy');
    DateFormat timeFormat = DateFormat('h:mm a');

    DateTime? openDt, closeDt;
    String openDate = "N/A",
        openTime = "N/A",
        closeDate = "N/A",
        closeTime = "N/A";

    try {
      if (shift['OpeningDateTime'] != null) {
        openDt = DateTime.parse(shift['OpeningDateTime']).toLocal();
        openDate = dateFormat.format(openDt);
        openTime = timeFormat.format(openDt);
      }
      if (shift['ClosingDateTime'] != null) {
        closeDt = DateTime.parse(shift['ClosingDateTime']).toLocal();
        closeDate = dateFormat.format(closeDt);
        closeTime = timeFormat.format(closeDt);
      }
      debugPrint(
        "Parsed DateTime values — open: $openDt ($openDate @ $openTime), close: $closeDt ($closeDate @ $closeTime)",
      );
    } catch (e, st) {
   
    }

    List bytes = [];

    bytes += generator.text(
      'Shift Close',
      styles: PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    );
    bytes += generator.text(
      'BestMummy\nSweets & Cakes',
      styles: PosStyles(align: PosAlign.center),
    );
    bytes += generator.feed(2);

    bytes += generator.row([
      PosColumn(
        width: 6,
        text: "Branch: ${shift['branchName'] ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text:
            'Date: ${DateFormat('dd-MM-yyyy').format(DateTime.now().toLocal())}',
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        width: 6,
        text: '',
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text: 'Time: ${DateFormat('HH:mm').format(DateTime.now())}',
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += generator.hr();

    bytes += generator.text("Shift Number: ${shift['shiftNumber'] ?? 'N/A'}");
    bytes += generator.text("Emp ID: ${shift['empId'] ?? 'N/A'}");
    bytes += generator.text("Emp Name: ${shift['empName'] ?? 'N/A'}");
    bytes += generator.row([
      PosColumn(
        width: 6,
        text: "Opening Date: $openDate",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text: 'Opening Time: $openTime',
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        width: 6,
        text: "Closing Date: $closeDate",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text: 'Closing Time: $closeTime',
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += generator.hr();

    bytes += generator.text(
      "Petty Cash",
      styles: PosStyles(bold: true, align: PosAlign.center),
    );
    bytes += generator.hr();

    bytes += generator.row([
      PosColumn(
        width: 6,
        text: "System Opening : ${shift['systemOpeningBalance'] ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text: 'Manual Opening : ${shift['manualOpeningBalance'] ?? 'N/A'}',
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        width: 6,
        text: "Difference: ${shift['openingDifferenceAmount'] ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
      PosColumn(
        width: 6,
        text: 'Type: ${shift['openingDifferenceType'] ?? 'N/A'}',
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        width: 6,
        text: "System Closing : ${shift['systemClosingBalance'] ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text: 'Manual Closing : ${shift['manualClosingBalance'] ?? 'N/A'}',
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        width: 6,
        text: "Difference: ${shift['closingDifferenceAmount'] ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
      PosColumn(
        width: 6,
        text: 'Type: ${shift['closingDifferenceType'] ?? 'N/A'}',
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);

    bytes += generator.hr();
    bytes += generator.text(
      "OverAll Sales",
      styles: PosStyles(bold: true, align: PosAlign.center),
    );
    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(
        width: 6,
        text: "System : ${shift['totalSystemSales'] ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text: 'Manual : ${shift['totalManualSales'] ?? 'N/A'}',
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        width: 6,
        text: "TakeAway: ${shift['totalTakeAwaySales'] ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
      PosColumn(
        width: 6,
        text: 'SaleOrder: ${shift['totalSaleOrderSales'] ?? 'N/A'}',
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        width: 6,
        text: "KOT: ${shift['totalKotSales'] ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
      PosColumn(
        width: 6,
        text: 'BDCake: ${shift['totalBdCakeSales'] ?? 'N/A'}',
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        width: 6,
        text: "Difference: ${shift['totalDifferenceAmount'] ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
      PosColumn(
        width: 6,
        text: 'Type: ${shift['totalDifferenceType'] ?? 'N/A'}',
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
    bytes += generator.hr();
    bytes += generator.text(
      "Cash Sales",
      styles: PosStyles(bold: true, align: PosAlign.center),
    );
    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(
        width: 6,
        text: "System : ${shift['systemCashSales'] ?? '0'}",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text: 'Manual : ${shift['manualCashsales'] ?? 'N/A'}',
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        width: 6,
        text: "TakeAway: ${shift['takeAwayCashSales'] ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
      PosColumn(
        width: 6,
        text: 'SaleOrder: ${shift['saleOrderCashSales'] ?? 'N/A'}',
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        width: 6,
        text: "KOT: ${shift['kotCashSales'] ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
      PosColumn(
        width: 6,
        text: 'BDCake: ${shift['bdCakeCashSales'] ?? 'N/A'}',
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        width: 6,
        text: "Difference: ${shift['cashSaleDifferenceAmount'] ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
      PosColumn(
        width: 6,
        text: 'Type: ${shift['cashSaleDifferenceType'] ?? 'N/A'}',
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);

    bytes += generator.hr();
    bytes += generator.text(
      "Card Sales",
      styles: PosStyles(bold: true, align: PosAlign.center),
    );
    bytes += generator.hr();

    bytes += generator.row([
      PosColumn(
        width: 6,
        text: "System : ${shift['systemCardSales'] ?? '0'}",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text: 'Manual : ${shift['manualCardsales'] ?? 'N/A'}',
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        width: 6,
        text: "TakeAway: ${shift['takeAwayCardSales'] ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
      PosColumn(
        width: 6,
        text: 'SaleOrder: ${shift['saleOrderCardSales'] ?? 'N/A'}',
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        width: 6,
        text: "KOT: ${shift['kotCardSales'] ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
      PosColumn(
        width: 6,
        text: 'BDCake: ${shift['bdCakeCardSales'] ?? 'N/A'}',
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        width: 6,
        text: "Difference: ${shift['cardSaleDifferenceAmount'] ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
      PosColumn(
        width: 6,
        text: 'Type: ${shift['cardSaleDifferenceType'] ?? 'N/A'}',
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);

    bytes += generator.hr();
    bytes += generator.text(
      "UPI Sales",
      styles: PosStyles(bold: true, align: PosAlign.center),
    );
    bytes += generator.hr();

    bytes += generator.row([
      PosColumn(
        width: 6,
        text: "System : ${shift['systemUpiSales'] ?? '0'}",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text: 'Manual : ${shift['manualUpisales'] ?? 'N/A'}',
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        width: 6,
        text: "TakeAway: ${shift['takeAwayUpiSales'] ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
      PosColumn(
        width: 6,
        text: 'SaleOrder: ${shift['saleOrderUpiSales'] ?? 'N/A'}',
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        width: 6,
        text: "KOT: ${shift['kotUpiSales'] ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
      PosColumn(
        width: 6,
        text: 'BDCake: ${shift['bdCakeUpiSales'] ?? 'N/A'}',
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        width: 6,
        text: "Difference: ${shift['upiSaleDifferenceAmount'] ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
      PosColumn(
        width: 6,
        text: 'Type: ${shift['upiSaleDifferenceType'] ?? 'N/A'}',
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
    bytes += generator.hr();

    bytes += generator.text(
      "Other Sales",
      styles: PosStyles(bold: true, align: PosAlign.center),
    );
    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(
        width: 6,
        text: "System : ${shift['otherSystemSales'] ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        width: 6,
        text: 'Manual : ${shift['otherManualsales'] ?? 'N/A'}',
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        width: 6,
        text: "TakeAway: ${shift['takeAwayOtherSales'] ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
      PosColumn(
        width: 6,
        text: 'SaleOrder: ${shift['saleOrderOtherSales'] ?? 'N/A'}',
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        width: 6,
        text: "KOT: ${shift['kotOtherSales'] ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
      PosColumn(
        width: 6,
        text: 'BDCake: ${shift['bdCakeOtherSales'] ?? 'N/A'}',
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        width: 6,
        text: "Difference: ${shift['otherSaleDifferenceAmount'] ?? 'N/A'}",
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
      PosColumn(
        width: 6,
        text: 'Type: ${shift['otherSaleDifferenceType'] ?? 'N/A'}',
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);

    bytes += generator.hr();
    bytes += generator.text(
      "Delivery Partner Sales: ${shift['deliveryPartnerSales'] ?? 'N/A'}",
    );
    bytes += generator.hr();
    bytes += generator.text("Sales Return: ${shift['salesReturn'] ?? 'N/A'}");
    bytes += generator.hr();

    bytes += generator.text(
      "Day End Status: ${shift['dayEndStatus'] ?? 'N/A'}",
    );
    bytes += generator.text("Status: ${shift['status'] ?? 'N/A'}");
    bytes += generator.text("Branch ID: ${shift['branchId'] ?? 'N/A'}");
    bytes += generator.text("Device ID: ${shift['deviceId'] ?? 'N/A'}");
    bytes += generator.text("Device Number: ${shift['deviceNumber'] ?? 'N/A'}");

    bytes += generator.hr();

    bytes += generator.text(
      "Generated at: ${dateFormat.format(DateTime.now())} ${timeFormat.format(DateTime.now())}",
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.feed(2);
    bytes += generator.cut();

    try {
      printer.rawBytes(Uint8List.fromList(bytes.cast<int>()));
      //printer.cut();
      printer.disconnect();
   
    } catch (e, st) {

    }
  }

  /// Post day-end data to API and print day-end report

  static Future<void> postDayEndData(
    Map<String, dynamic> dayEndPost,
    context,
  ) async {
    //const String url = 'http://192.168.29.8:8888/dayEnd/dayend';
    const String url = 'https://yenerp.com/fastapi/dayends/dayend';
    // const String url = 'https://www.yenerp.com/fastapi/dayends/';
    try {
      final response = await _dio.post(url, data: json.encode(dayEndPost));
      final shifts = await CashManagementProvider.fetchShiftDetails();
     
      final dayEndList = await CashManagementProvider().fetchDayEndDetails();

      final dayEnd = (dayEndList is List && dayEndList.isNotEmpty)
          ? dayEndList.last
          : <String, dynamic>{};

      await CashManagementProvider().printOpenDayEndShifts(dayEnd, shifts);
      await CashManagementProvider().patchDayEnd(branchName);
      await fetchDispatchDetails();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('DayEnded successfully!')));
      }

      if (response.statusCode != 200) {
        debugPrint(
          'Failed to post day end data: ${response.statusCode} ${response.data}',
        );
      }
    } catch (e) {
      debugPrint('Error posting day end data: $e');
    }
  }

  static Future<List<Map<String, String>>> fetchValidationDetails() async {
    String apiUrl =
        "https://yenerp.com/fastapi/dayendvalidations/Validation?branchName=$branchName";
   
    try {
      final response = await _dio.get(apiUrl);

      if (response.statusCode == 200) {
        dynamic raw = response.data is String
            ? json.decode(response.data)
            : response.data;

        List<dynamic> listData;
        if (raw is List<dynamic>) {
          listData = raw;
        } else if (raw is Map<String, dynamic>) {
          // wrap single map in list
          listData = [raw];
        } else {
          // unknown type
      
          return [];
        }

        if (listData.isEmpty) return [];

        return listData.map<Map<String, String>>((v) {
          dispatchStatus.value = v['dispatchStatus']?.toString() ?? "";
          itemTransferStatus.value = v['itemTransferStatus']?.toString() ?? "";
          soApprovalStatus.value = v['soApprovalsStatus']?.toString() ?? "";
          storeStatus.value = v['storeDispatchStatus']?.toString() ?? "";
          soDeliveryStatus.value = v['soDeliveryStatus']?.toString() ?? "";

          return {
            "status": v['status']?.toString() ?? "",
            "dayEndId": v['dayEndId']?.toString() ?? "",
            "branchName": v['branchName']?.toString() ?? "",
            "soApprovalsStatus": v['soApprovalsStatus']?.toString() ?? "",
            "soPendings": v['soPendings']?.toString() ?? "",
            "soDeliveryStatus": v['soDeliveryStatus']?.toString() ?? "",
            "soDeliveryPendings": v['soDeliveryPendings']?.toString() ?? "",
            "dispatchStatus": v['dispatchStatus']?.toString() ?? "",
            "dispatchPendings": v['dispatchPendings']?.toString() ?? "",
            "itemTransferStatus": v['itemTransferStatus']?.toString() ?? "",
            "itemTransferPendings": v['itemTransferPendings']?.toString() ?? "",
            "storeDispatchStatus": v['storeDispatchStatus']?.toString() ?? "",
            "storeDispatchPendings":
                v['storeDispatchPendings']?.toString() ?? "",
          };
        }).toList();
      } else {
        debugPrint(
          "❌ fetch Validation Details: status code ${response.statusCode}",
        );
      }
    } catch (e, st) {
      
    }
    return [];
  }

  static Future<List<Map<String, String>>> fetchDispatchDetails() async {
    final now = DateTime.now();
    final formattedDate = DateFormat('dd-MM-yyyy').format(now);
    String apiUrl =
        "https://yenerp.com/fastapi/dispatches/?start_date=$formattedDate&end_date=$formattedDate";

    try {
      final response = await _dio.get(apiUrl);

      if (response.statusCode == 200) {
        List<dynamic> dispatch = response.data is String
            ? json.decode(response.data)
            : response.data;

        if (dispatch.isEmpty) return [];

        // Pick only needed fields + debug print
        return (dispatch as List<dynamic>).map<Map<String, String>>((d) {
          dispatchStatus.value = d['status']?.toString() ?? "";
        

          return {"status": d['status']?.toString() ?? ""};
        }).toList();
      }
    } catch (e, st) {
     
    }
    return [];
  }

  static Future<String> fetchShiftOpenCheck() async {
    String apiUrl =
        "https://yenerp.com/fastapi/dayendvalidations/status?empId=$empId&branchName=$branchName";

    try {
      final response = await _dio.get(apiUrl);

      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        // Expect data is Map<String, dynamic>
        if (data is Map<String, dynamic>) {
          final status = data['shiftStatus']?.toString() ?? "";
          shiftOpenStatus.value = status;
          
          return status;
        } else {
          // Unexpected type
          
        }
      } else {
     
      }
    } catch (e, st) {
     
    }
    return "";
  }

  // Patch day-end data to API

  Future<List<Map<String, dynamic>>> patchDayEnd(String branchName) async {
    String apiUrl = "https://yenerp.com/fastapi/shifts/dayend/$branchName";
    //String apiUrl = "http://192.168.29.8:8888/shift/dayend/$branchName";s
  

    try {
      final response = await _dio.patch(
        apiUrl,
        data: {}, // No request body needed
      );

      if (response.statusCode == 200 && response.data is List) {
        final List<dynamic> dataList = response.data as List<dynamic>;

        final result = dataList.map<Map<String, dynamic>>((item) {
          return Map<String, dynamic>.from(item as Map);
        }).toList();

        if (kDebugMode) {
          debugPrint(
            'PATCH /dayend/$branchName SUCCESS: ${result.length} shifts updated.',
          );
        }
        return result;
      } else {
        if (kDebugMode) {
          debugPrint('Unexpected status or data: ${response.statusCode}');
        }
        return [];
      }
    } on DioError catch (e) {
      final msg = e.response != null
          ? 'DioError: HTTP ${e.response?.statusCode}, data: ${e.response?.data}'
          : 'DioError: ${e.message}';
      debugPrint(msg);
      return [];
    } catch (e, st) {
      debugPrint('Error in patchDayEnd: $e\n$st');
      return [];
    }
  }

  /// ------------------ Denomination helpers ------------------
  static void updateDenominationCount(int denomination, int count) {
    final updated = Map<int, int>.from(denominationCounts.value);
    updated[denomination] = count;
    denominationCounts.value = updated;
    _recalcPhysicalTotal();
  }

  static void _recalcPhysicalTotal() {
    final map = denominationCounts.value;
    int total = 0;
    for (final entry in map.entries) {
      total += entry.key * entry.value;
    }
    physicalCashSales.value = total;
  }

  /// mirror original "Save 2" behaviour
  static void persistDenominationsToStore() {
    // If you had GetX controllers previously, this is where you'd push to them.
    // For parity, we leave it as a placeholder (no-op or hook to your store).
    // Example:
    // totals.forEach((denomination, value) { denomController.update(denom, count); });
  }

  /// ------------------ ESC/POS sample (if needed) ------------------
  static Future<void> printStoreReceipt(String ip) async {
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm80, profile);
    final PosPrintResult connectionResult = await printer.connect(
      ip,
      port: 9100,
    );
    if (connectionResult == PosPrintResult.success) {
      final generator = Generator(PaperSize.mm80, profile);
      final bytes = <int>[];
      bytes.addAll(
        generator.text(
          'BestMummy',
          styles: PosStyles(align: PosAlign.center, bold: true),
        ),
      );
      bytes.addAll(
        generator.text(
          'Sweets & Cakes',
          styles: PosStyles(align: PosAlign.center),
        ),
      );
      bytes.addAll(
        generator.text(
          'Dispatch',
          styles: PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            bold: true,
          ),
        ),
      );
      bytes.addAll(generator.feed(1));
      bytes.addAll(generator.hr());
      bytes.addAll(generator.feed(2));
      bytes.addAll(generator.cut());
      printer.rawBytes(Uint8List.fromList(bytes));
      await Future.delayed(const Duration(seconds: 1));
      printer.disconnect();
    } else {
  
    }
  }

  /// ------------------ Calculations (same as your originals) ------------------
  static String calculateDifference(
    String? systemClosing,
    String? manualClosing,
  ) {
    double system = double.tryParse(systemClosing ?? '0') ?? 0;
    double manual = double.tryParse(manualClosing ?? '0') ?? 0;
    return (system - manual).toStringAsFixed(2);
  }

  static String calculateTotal(List<Map<String, String>> shifts, String key) {
    return shifts
        .map((shift) => double.tryParse(shift[key] ?? '0') ?? 0)
        .fold<double>(0, (a, b) => a + b)
        .toStringAsFixed(2);
  }

  static String calculateTotalDifferences(List<Map<String, String>> shifts) {
    return shifts
        .map((shift) => double.tryParse(shift["Difference"] ?? '0')?.abs() ?? 0)
        .fold<double>(0, (a, b) => a + b)
        .toStringAsFixed(2);
  }

  static String calculateTotalSales(Map<String, dynamic> data) {
    List<String> keys = ['cardSales', 'upiSales', 'swiggySales', 'zomatoSales'];
    return keys
        .map((key) {
          final value = data[key];
          if (value is String) return double.tryParse(value) ?? 0;
          if (value is num) return value.toDouble();
          return 0.0;
        })
        .fold<double>(0, (a, b) => a + b)
        .toStringAsFixed(2);
  }

  static String calculateOverallSales(Map<String, dynamic> data) {
    List<String> keys = [
      'systemClosingBalance',
      'manualClosingBalance',
      'cardSales',
      'upiSales',
      'swiggySales',
      'zomatoSales',
    ];
    final total = keys.fold<double>(0, (prev, key) {
      final v = data[key];
      if (v is String) return prev + (double.tryParse(v) ?? 0);
      if (v is num) return prev + v.toDouble();
      return prev;
    });
    return total.toStringAsFixed(2);
  }

  // final List<int> denomList;
  //  final List<int> denomList = [500, 200, 100, 50, 20, 10];
  // final Map<int, TextEditingController> controllers = {};
  // final Map<int, FocusNode> focusNodes = {};

  // // map denom -> total for that denom (denom * count)
  // Map<int, int> denominationTotals = {};

  // // which denom is active (keyboard shown, input is for this)
  // int? currentDenomForKeyboard;

  // DenominationModel() {
  //   for (var d in denomList) {
  //     controllers[d] = TextEditingController();
  //     focusNodes[d] = FocusNode();
  //     denominationTotals[d] = 0;
  //   }
  // }

  // // Call when number pressed in keyboard
  // void onNumberPressed(String digit) {
  //   if (currentDenomForKeyboard == null) return;
  //   final denom = currentDenomForKeyboard!;
  //   final ctrl = controllers[denom]!;
  //   ctrl.text = ctrl.text + digit;
  //   final count = int.tryParse(ctrl.text) ?? 0;
  //   denominationTotals[denom] = denom * count;
  //   notifyListeners();
  // }

  // void onClear() {
  //   if (currentDenomForKeyboard == null) return;
  //   final denom = currentDenomForKeyboard!;
  //   final ctrl = controllers[denom]!;
  //   ctrl.clear();
  //   denominationTotals[denom] = 0;
  //   notifyListeners();
  // }

  // void onOk() {
  //   if (currentDenomForKeyboard == null) return;
  //   final denom = currentDenomForKeyboard!;
  //   final idx = denomList.indexOf(denom);
  //   if (idx < denomList.length - 1) {
  //     final nextDenom = denomList[idx + 1];
  //     currentDenomForKeyboard = nextDenom;
  //     // move focus
  //     focusNodes[nextDenom]!.requestFocus();
  //   } else {
  //     currentDenomForKeyboard = null;
  //     FocusScopeNode scope = FocusScope.of(focusNodes[denom]!.context!);
  //     scope.unfocus();
  //   }
  //   notifyListeners();
  // }

  // int get grandTotal {
  //   return denominationTotals.values.fold(0, (sum, v) => sum + v);
  // }

  // void activateKeyboard(int denom) {
  //   currentDenomForKeyboard = denom;
  //   focusNodes[denom]!.requestFocus();
  //   notifyListeners();
  // }
}
