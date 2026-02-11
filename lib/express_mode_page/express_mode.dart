import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:yen_pos/Global/Provider/branchwise_item_fetch.dart';
import 'package:yen_pos/Global/Widget/custom_textWidgets.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/regular_mode_page/provider/regular_mode_screen_provider.dart';
import 'package:yen_pos/regular_mode_page/provider/cart_page_provider.dart';
import 'package:yen_pos/regular_mode_page/widget/current_sale_section.dart';

// class ExpressModeScreen extends StatefulWidget {
//   const ExpressModeScreen({Key? key}) : super(key: key);
//   @override
//   State<ExpressModeScreen> createState() => _ExpressModeScreenState();
// }

// class _ExpressModeScreenState extends State<ExpressModeScreen> {
//   // ──────────────────────────────────────────────────────────────
//   //  Hidden scanner field (always focused, off-screen)
//   // ──────────────────────────────────────────────────────────────
//   final FocusNode _scannerFocus = FocusNode();
//   final TextEditingController _scannerController = TextEditingController();
//   final AudioPlayer _audioPlayer = AudioPlayer();

//   bool _isProcessing = false;

//   @override
//   void initState() {
//     super.initState();
//     // Keep focus forever
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _scannerFocus.requestFocus();
//     });
//   }

//   @override
//   void dispose() {
//     _scannerFocus.dispose();
//     _scannerController.dispose();
//     _audioPlayer.dispose();
//     super.dispose();
//   }

//   // ──────────────────────────────────────────────────────────────
//   //  Beep sound (optional but nice)
//   // ──────────────────────────────────────────────────────────────
//   Future<void> _playBeep() async {
//     try {
//       await _audioPlayer.stop();
//       await _audioPlayer.play(AssetSource('beep.mp3'));
//     } catch (e) {
//       debugPrint('Beep failed: $e');
//     }
//   }

//   // ──────────────────────────────────────────────────────────────
//   //  Parse QR / barcode
//   // ──────────────────────────────────────────────────────────────
//   Map<String, dynamic> _parse(String raw) {
//     try {
//       return json.decode(raw);
//     } catch (_) {
//       final map = <String, dynamic>{};
//       raw.replaceAll('{', '').replaceAll('}', '').split(',').forEach((pair) {
//         final kv = pair.split(':');
//         if (kv.length == 2) map[kv[0].trim()] = kv[1].trim();
//       });
//       return map;
//     }
//   }

//   double _toDouble(dynamic v) =>
//       (v is num) ? v.toDouble() : (double.tryParse(v.toString()) ?? 0.0);

//   Future<void> _handleScan(String raw) async {
//   if (_isProcessing || raw.isEmpty) return;
//   setState(() => _isProcessing = true);

//   await _playBeep();

//   try {
//     final data = _parse(raw);
//     if (!data.containsKey('ItemCode')) {
//       _snack('Invalid QR – no ItemCode');
//       return;
//     }

//     final itemCode = data['ItemCode'];
//     final qty = data['Qty'] ?? 1;
//     final uom = data['UOM'] ?? '';

//     final itemProvider = Provider.of<ItemProvider>(context, listen: false);
//     final matches =await itemProvider.checkVarianceItemCode(itemCode,aliasname);

//     if (matches.isEmpty) {
//       _snack('Item not found: $itemCode');
//       return;
//     }

//     final item = matches.first;

//     final stock = _toDouble(item['varianceData']['variance_Stock'] ?? 0);

//     if (stock <= 0) {
//       _snack('Out of Stock: ${item['varianceData']['varianceName']}');
//       return;
//     }

//     if (_toDouble(qty) > stock) {
//       _snack(
//         'Only $stock available, but scanned qty = ${_toDouble(qty)}',
//       );
//       return;
//     }

//     final saleProvider = Provider.of<CurrentSaleProvider>(context, listen: false);

//     saleProvider.addItemToCartExpressMode({
//       ...item,
//       'quantity': _toDouble(qty),
//       'uom': uom,
//       'varianceData': {
//         ...item['varianceData'],
//         'variance_Defaultprice':
//             _toDouble(item['varianceData']['variance_Defaultprice']),
//       },
//     });

//     _snack('Added: ${item['varianceData']['varianceName']} × ${_toDouble(qty)}');
//   } catch (e) {
//     _snack('Error: $e');
//   } finally {
//     _scannerController.clear();
//     _scannerFocus.requestFocus();
//     setState(() => _isProcessing = false);
//   }
// }

//   void _snack(String msg) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(msg, style: const TextStyle(color: Colors.white)),
//         backgroundColor: Colors.blue,
//         duration: const Duration(milliseconds: 600),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return ChangeNotifierProvider(
//       create: (_) => RegularModeProvider(),
//       child: MaterialApp(
//         debugShowCheckedModeBanner: false,
//         home: SafeArea(
//           child: Scaffold(
//             resizeToAvoidBottomInset: false,
//             backgroundColor: Colors.white,
//             body: GestureDetector(
//               // Keep scanner focused when user taps anywhere
//               onTap: () => _scannerFocus.requestFocus(),
//               child: Stack(
//                 children: [
//                   // ───── MAIN LAYOUT ─────
//                   Consumer<RegularModeProvider>(
//                     builder: (context, provider, _) {
//                       return Column(
//                         children: [
//                           Expanded(
//                             child: Row(
//                               children: [
//                                 // ─── LEFT PANEL ───
//                                 Expanded(
//                                   flex: 2,
//                                   child: Column(
//                                     children: [
//                                       const SizedBox(height: 16),

//                                       // Loading / Empty
//                                       Expanded(
//                                         child: provider.isLoading
//                                             ? const Center(child: CircularProgressIndicator())
//                                             : provider.items.isEmpty
//                                                 ? const Center(
//                                                     child: CustomText(
//                                                       text: "Please scan the items",
//                                                       style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueGrey),
//                                                     ),
//                                                   )
//                                                 : const Center(
//                                                     child: Text(
//                                                       "Scan to add items",
//                                                       style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
//                                                     ),
//                                                   ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),

//                                 const VerticalDivider(width: 1),

//                                 // ─── RIGHT PANEL (CART) ───
//                                 Expanded(
//                                   flex: 1,
//                                   child: RepaintBoundary(child: CurrentSaleSection()),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       );
//                     },
//                   ),

//                   // ───── HIDDEN SCANNER FIELD (OFF-SCREEN) ─────
//                   Positioned(
//                     left: -100,
//                     top: -100,
//                     child: Opacity(
//                       opacity: 0,
//                       child: SizedBox(
//                         width: 1,
//                         height: 1,
//                         child: TextField(
//                           key: const Key('expressScannerField'),
//                           controller: _scannerController,
//                           focusNode: _scannerFocus,
//                           autofocus: true,
//                           showCursor: false,
//                           enableInteractiveSelection: false,
//                           // ←←← IMPORTANT: allow real keyboard (USB scanner)
//                           keyboardType: TextInputType.none,
//                           style: const TextStyle(fontSize: 1, color: Colors.transparent),
//                           decoration: const InputDecoration(border: InputBorder.none),

//                           // Most USB scanners send Enter → onSubmitted
//                           onSubmitted: (v) => _handleScan(v.trim()),

//                           // Fallback: some send \n inside the string
//                           onChanged: (v) {
//                             if (v.contains('\n') || v.contains('\r')) {
//                               final clean = v.replaceAll(RegExp(r'[\n\r]'), '').trim();
//                               if (clean.isNotEmpty) _handleScan(clean);
//                               _scannerController.clear();
//                             }
//                           },
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

class ExpressModeScreen extends StatefulWidget {
  const ExpressModeScreen({Key? key}) : super(key: key);

  @override
  State<ExpressModeScreen> createState() => _ExpressModeScreenState();
}

class _ExpressModeScreenState extends State<ExpressModeScreen> {
  final FocusNode _scannerFocus = FocusNode();
  final TextEditingController _scannerController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scannerFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _scannerFocus.dispose();
    _scannerController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Beep
  // ─────────────────────────────────────────────
  Future<void> _playBeep() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('beep.mp3'));
    } catch (_) {}
  }

  // ─────────────────────────────────────────────
  // Parse QR (JSON or plain ID)
  // ─────────────────────────────────────────────
  Map<String, dynamic> _parse(String raw) {
    try {
      return json.decode(raw);
    } catch (_) {
      return {'id': raw.trim()};
    }
  }

  double _toDouble(dynamic v) =>
      (v is num) ? v.toDouble() : (double.tryParse(v.toString()) ?? 0.0);

  // ─────────────────────────────────────────────
  // 🔥 GET ITEM FROM HIVE USING ID
  // ─────────────────────────────────────────────
  Map<String, dynamic>? _getItemFromHive(String id) {
    final box = Hive.box('qr');
    final Map<String, dynamic>? qrMap = box
        .get('qrMap')
        ?.cast<String, dynamic>();

    return qrMap?[id];
  }

  // ─────────────────────────────────────────────
  // HANDLE SCAN (FIXED)
  // ─────────────────────────────────────────────
  Future<void> _handleScan(String raw) async {
    if (_isProcessing || raw.isEmpty) return;
    setState(() => _isProcessing = true);

    await _playBeep();

    try {
      final parsed = _parse(raw);
      final String id = parsed['id'].toString();

      // 🔥 GET DATA FROM HIVE
      final hiveItem = _getItemFromHive(id);

      if (hiveItem == null) {
        _snack('Item not found: $id');
        return;
      }

      final itemCode = hiveItem['itemCode'];
      final qty = hiveItem['qty'] ?? 1;
      final uom = hiveItem['uom'] ?? '';

      // ⚠️ YOUR EXISTING FLOW (UNCHANGED)
      final itemProvider = Provider.of<ItemProvider>(context, listen: false);

      final matches = await itemProvider.checkVarianceItemCode(
        locationId,
        itemCode,
      );

      if (matches.isEmpty) {
        _snack('Item not found');
        return;
      }

      final item = matches.first;
      final stock = _toDouble(
        item['varianceData']['branchwise']['$locationId']['systemStock'] ?? 0,
      );

      if (stock <= 0) {
        _snack('Out of Stock: ${item['varianceData']['varianceName']}');
        return;
      }

      if (_toDouble(qty) > stock) {
        _snack('Only $stock available');
        return;
      }

      final saleProvider = Provider.of<CurrentSaleProvider>(
        context,
        listen: false,
      );

      saleProvider.addItemToCartExpressMode({
        ...item,
        'quantity': _toDouble(qty),
        'uom': uom,
        'varianceData': {
          ...item['varianceData'],
          'variance_Defaultprice': _toDouble(
            item['varianceData']['variance_Defaultprice'],
          ),
        },
      });

      _snack(
        'Added: ${item['varianceData']['varianceName']} × ${_toDouble(qty)}',
      );
    } catch (e) {
      _snack('Error: $e');
    } finally {
      _scannerController.clear();
      _scannerFocus.requestFocus();
      setState(() => _isProcessing = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        duration: const Duration(milliseconds: 600),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // UI (UNCHANGED)
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RegularModeProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SafeArea(
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: Colors.white,
            body: GestureDetector(
              onTap: () => _scannerFocus.requestFocus(),
              child: Stack(
                children: [
                  Consumer<RegularModeProvider>(
                    builder: (context, provider, _) {
                      return Column(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Center(
                                    child: provider.items.isEmpty
                                        ? const Text(
                                            "Please scan the items",
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : const Text("Scan to add items"),
                                  ),
                                ),
                                const VerticalDivider(width: 1),
                                Expanded(
                                  flex: 1,
                                  child: RepaintBoundary(
                                    child: CurrentSaleSection(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  // ─── HIDDEN SCANNER FIELD ───
                  Positioned(
                    left: -100,
                    top: -100,
                    child: Opacity(
                      opacity: 0,
                      child: SizedBox(
                        width: 1,
                        height: 1,
                        child: TextField(
                          controller: _scannerController,
                          focusNode: _scannerFocus,
                          autofocus: true,
                          showCursor: false,
                          keyboardType: TextInputType.none,
                          onSubmitted: (v) => _handleScan(v.trim()),
                          onChanged: (v) {
                            if (v.contains('\n') || v.contains('\r')) {
                              final clean = v
                                  .replaceAll(RegExp(r'[\n\r]'), '')
                                  .trim();
                              if (clean.isNotEmpty) _handleScan(clean);
                              _scannerController.clear();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
