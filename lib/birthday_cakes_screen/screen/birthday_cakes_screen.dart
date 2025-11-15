import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/Provider/branchwise_item_fetch.dart';
import 'package:yenpos/Global/Widget/custom_colors.dart';
import 'package:yenpos/birthday_cakes_screen/models/birthdayCake_model.dart';
import 'package:yenpos/birthday_cakes_screen/provider/birthdayCake_provider.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/salesInvoicePayandPrint.dart';

import '../../regular_mode_page/provider/cart_page_provider.dart';
import '../../regular_mode_page/widget/current_sale_section.dart';

class BirthdayCakesScreen extends StatefulWidget {
  const BirthdayCakesScreen({super.key});

  @override
  State<BirthdayCakesScreen> createState() => _BirthdayCakesScreenState();
}

class _BirthdayCakesScreenState extends State<BirthdayCakesScreen> with RouteAware {
  final FocusNode _qrFocusNode = FocusNode();
  final FocusNode _manualFocusNode = FocusNode();
  final TextEditingController _manualController = TextEditingController();
  final TextEditingController _qrController = TextEditingController();

  bool _isProcessing = false;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isAtTopNotifier = ValueNotifier<bool>(true);
  RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
  MobileScannerController _scannerController = MobileScannerController();
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'QR');
  final AudioPlayer _audioPlayer = AudioPlayer(); // Add audio player

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _manualFocusNode.addListener(_onFocusChange);

    // Ensure keyboard is hidden initially
    _manualFocusNode.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<BirthdayCakesProvider>(context, listen: false);
      provider.setTextFieldFocused(false);
      provider
          .fetchCakes()
          .then((_) {
            print('Fetched cakes: ${provider.cakes.map((c) => c.cakeId).toList()}');
          })
          .catchError((e) {
            print('Error fetching cakes: $e');
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Failed to load cakes: $e'), duration: const Duration(seconds: 2)));
          });
      if (provider.isQrMode) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _qrFocusNode.requestFocus(); // ensure scanner field is ready
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void didPopNext() {
    final provider = Provider.of<BirthdayCakesProvider>(context, listen: false);
    _manualFocusNode.unfocus();
    _manualController.clear();
    _qrController.clear();
    provider.setTextFieldFocused(false);
    provider.setCameraMode(false);
    print('Returned to BirthdayCakesScreen, keyboard hidden, camera mode off');
    super.didPopNext();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _qrFocusNode.dispose();
    _manualFocusNode.dispose();
    _manualController.dispose();
    _qrController.dispose();
    _scrollController.dispose();
    _isAtTopNotifier.dispose();
    _scannerController.dispose();
    _audioPlayer.dispose(); // Dispose audio player
    super.dispose();
  }

  Future<void> _playBeepSound() async {
    try {
      print('Attempting to play beep.mp3 from assets');
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: [AVAudioSessionOptions.defaultToSpeaker, AVAudioSessionOptions.mixWithOthers],
          ),
        ),
      );
      await _audioPlayer.play(AssetSource('beep.mp3'));
      print('Beep sound played successfully');
    } catch (e, stackTrace) {
      print('Error playing beep sound: $e\nStack trace: $stackTrace');
      // Fallback to vibration

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Scan successful, but audio failed: $e'), duration: Duration(milliseconds: 500)));
    }
  }

  void _onScroll() {
    final isAtTop = _scrollController.offset <= 0;
    if (_isAtTopNotifier.value != isAtTop) {
      _isAtTopNotifier.value = isAtTop;
    }
  }

  void _onFocusChange() {
    final provider = Provider.of<BirthdayCakesProvider>(context, listen: false);
    print('Focus changed: _manualFocusNode.hasFocus = ${_manualFocusNode.hasFocus}');
    provider.setTextFieldFocused(_manualFocusNode.hasFocus);
  }

  void _toggleQrMode() {
    final provider = Provider.of<BirthdayCakesProvider>(context, listen: false);
    _manualController.clear();
    provider.toggleQrMode();
    provider.setCameraMode(false);
    if (provider.isQrMode) {
      _qrFocusNode.requestFocus();
      _manualFocusNode.unfocus();
      provider.setTextFieldFocused(false);
    } else {
      _manualFocusNode.requestFocus();
      _qrFocusNode.unfocus();
      provider.setTextFieldFocused(true);
    }
    print('Toggled to ${provider.isQrMode ? "QR" : "Manual"} mode');
  }

  void _toggleCameraMode() {
    final provider = Provider.of<BirthdayCakesProvider>(context, listen: false);
    _manualController.clear();
    provider.toggleCameraMode();
    if (provider.isCameraMode) {
      _qrFocusNode.unfocus();
      _manualFocusNode.unfocus();
      provider.setTextFieldFocused(false);
      provider.setQrMode(false);
    } else {
      _qrFocusNode.requestFocus();
      provider.setQrMode(true);
    }
    print('Toggled to ${provider.isCameraMode ? "Camera" : "QR"} mode');
  }

  void _handleInput(String value) async {
    final provider = Provider.of<BirthdayCakesProvider>(context, listen: false);
    if (_isProcessing || (!provider.isQrMode && !provider.isCameraMode) || value.isEmpty) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Play beep sound when scan is successful
      await _playBeepSound();

      final Map<String, dynamic> scannedData = _parseScannedData(value);

      if (scannedData.containsKey('CakeID') && scannedData.containsKey('ItemCode')) {
        final itemCode = scannedData['ItemCode'];
        final cakeId = scannedData['CakeID'];
        final quantity = scannedData['Qty'] ?? 1;
        final uom = scannedData['UOM'] ?? '';

        final itemProvider = Provider.of<ItemProvider>(context, listen: false);
        final saleProvider = Provider.of<CurrentSaleProvider>(context, listen: false);

        print('Scanned CakeID: $cakeId');

        final matchingCake =
            provider.getCakeById(cakeId) ??
            BirthDayCake(
              itemCode: '',
              varianceName: '',
              cakeId: '',
              productionDate: DateTime.now(),
              expiryDate: DateTime.now(),
              id: '',
              branchName: '',
              selfLife: 0,
              status: '',
              manufacture: '',
              recievedDate: DateTime.now(),
            );

        if (matchingCake.cakeId.isNotEmpty) {
          final expiryDate = matchingCake.expiryDate.toLocal();
          final now = DateTime.now();
          final nowDate = DateTime(now.year, now.month, now.day);
          final expiryDateOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
          final daysRemaining = expiryDateOnly.difference(nowDate).inDays;

          if (daysRemaining < 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Cannot add to cart: Cake with CakeID $cakeId is expired."),
                duration: const Duration(milliseconds: 500),
              ),
            );
            return;
          }

          provider.removeCakeById(cakeId);

          final result = itemProvider.checkVarianceItemCode(itemCode);

          if (result.isNotEmpty) {
            final itemData = result.first;

            saleProvider.addItemToCart({...itemData, 'quantity': parseToDouble(quantity), 'uom': uom, 'cakeId': cakeId});

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: CustomColors.blueColor,
                content: Text(
                  "Item added to cart: ${itemData['varianceData']['varianceName']}",
                  style: const TextStyle(fontFamily: 'Poppins',color: CustomColors.whiteColor),
                ),
                duration: const Duration(milliseconds: 500),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Item not found for ItemCode: $itemCode"), duration: const Duration(milliseconds: 500)),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("No cake found with CakeID: $cakeId. Item not added to cart."),
              duration: const Duration(milliseconds: 500),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid QR data. 'CakeID' or 'ItemCode' not found."),
            duration: const Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      print('Error processing QR input: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}"), duration: const Duration(milliseconds: 500)));
    } finally {
      _qrController.clear();
      if (provider.isCameraMode) {
        // Keep camera active
      } else {
        _qrFocusNode.requestFocus();
      }
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // ... Rest of your existing methods remain the same (handleManualAdd, parseScannedData, etc.)

  void _handleManualAdd(String cakeId) async {
    final provider = Provider.of<BirthdayCakesProvider>(context, listen: false);
    if (cakeId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter a valid Cake ID."), duration: Duration(milliseconds: 500)));
      return;
    }

    try {
      // Play beep sound for manual add as well (optional)
      await _playBeepSound();

      final itemProvider = Provider.of<ItemProvider>(context, listen: false);
      final saleProvider = Provider.of<CurrentSaleProvider>(context, listen: false);

      final matchingCake =
          provider.getCakeById(cakeId) ??
          BirthDayCake(
            itemCode: '',
            varianceName: '',
            cakeId: '',
            productionDate: DateTime.now(),
            expiryDate: DateTime.now(),
            id: '',
            branchName: '',
            selfLife: 0,
            status: '',
            manufacture: '',
            recievedDate: DateTime.now(),
          );

      if (matchingCake.cakeId.isNotEmpty) {
        final expiryDate = matchingCake.expiryDate.toLocal();
        final now = DateTime.now();
        final nowDate = DateTime(now.year, now.month, now.day);
        final expiryDateOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
        final daysRemaining = expiryDateOnly.difference(nowDate).inDays;

        if (daysRemaining < 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Cannot add to cart: Cake with CakeID $cakeId is expired."),
              duration: const Duration(milliseconds: 500),
            ),
          );
          return;
        }

        provider.removeCakeById(cakeId);

        final result = itemProvider.checkVarianceItemCode(matchingCake.itemCode);

        if (result.isNotEmpty) {
          final itemData = result.first;

          saleProvider.addItemToCart({...itemData, 'quantity': 1.0, 'uom': '', 'cakeId': cakeId});

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Item added to cart: ${itemData['varianceData']['varianceName']}"),
              duration: const Duration(milliseconds: 500),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Item not found for CakeID: $cakeId"), duration: const Duration(milliseconds: 500)),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("No cake found with CakeID: $cakeId. Item not added to cart."),
            duration: const Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      print('Error processing manual input: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}"), duration: const Duration(milliseconds: 500)));
    } finally {
      _manualController.clear();
      if (!provider.isQrMode && !provider.isCameraMode) {
        _manualFocusNode.requestFocus();
      }
    }
  }

  Map<String, dynamic> _parseScannedData(String value) {
    try {
      return json.decode(value);
    } catch (_) {
      final Map<String, dynamic> parsedData = {};
      value.replaceAll('{', '').replaceAll('}', '').split(',').forEach((pair) {
        final keyValue = pair.split(':');
        if (keyValue.length >= 2) {
          final key = keyValue[0].trim();
          final value = keyValue.sublist(1).join(':').trim();
          parsedData[key] = value;
        }
      });
      return parsedData;
    }
  }

  Map<String, List<Map<String, dynamic>>> groupCakesByDateAndItem(List<BirthDayCake> cakes) {
    Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var cake in cakes) {
      String dateKey = cake.recievedDate.toLocal().toString().split(" ")[0];

      if (!grouped.containsKey(dateKey)) grouped[dateKey] = [];

      var existing = grouped[dateKey]!.firstWhere((e) => e['itemCode'] == cake.itemCode, orElse: () => {});

      if (existing.isNotEmpty) {
        existing['count'] += 1;
        existing['cakes'].add(cake);
      } else {
        grouped[dateKey]!.add({
          'itemCode': cake.itemCode,
          'varianceName': cake.varianceName,
          'count': 1,
          'cakes': [cake],
        });
      }
    }

    return grouped;
  }

  double parseToDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  bool _isAtTop() {
    return !_scrollController.hasClients || _scrollController.offset <= 0;
  }

  void _toggleScrollPosition() {
    if (!_scrollController.hasClients) return;

    if (_isAtTop()) {
      _scrollController
          .animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          )
          .then((_) {
            _isAtTopNotifier.value = false;
          });
    } else {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut).then((_) {
        _isAtTopNotifier.value = true;
      });
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupByReceived(List<BirthDayCake> cakes) {
    return _groupCakes(cakes, (c) => c.recievedDate);
  }

  Map<String, List<Map<String, dynamic>>> _groupByExpiry(List<BirthDayCake> cakes) {
    return _groupCakes(cakes, (c) => c.expiryDate);
  }

  Map<String, List<Map<String, dynamic>>> _groupCakes(List<BirthDayCake> cakes, DateTime Function(BirthDayCake) dateGetter) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var cake in cakes) {
      final dateKey = dateGetter(cake).toLocal().toString().split(" ")[0];

      grouped.putIfAbsent(dateKey, () => []);

      final existing = grouped[dateKey]!.firstWhereOrNull((e) => e['itemCode'] == cake.itemCode);

      if (existing != null) {
        existing['count'] += 1;
        existing['cakes'].add(cake);
      } else {
        grouped[dateKey]!.add({
          'itemCode': cake.itemCode,
          'varianceName': cake.varianceName,
          'count': 1,
          'cakes': [cake],
        });
      }
    }

    // ---- FIFO sorting (oldest first) ----
    final sortedKeys = grouped.keys.toList()..sort((a, b) => a.compareTo(b)); // ascending = FIFO

    final ordered = <String, List<Map<String, dynamic>>>{};
    for (final k in sortedKeys) ordered[k] = grouped[k]!;
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SafeArea(
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: CustomColors.whiteColor,
          body: Consumer<BirthdayCakesProvider>(
            builder: (context, provider, child) {
              return Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        Expanded(
                                          flex: 1,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                            child: Column(
                                              children: [
                                                TextField(
                                                  cursorColor: CustomColors.blueColor,
                                                  controller: _manualController,
                                                  focusNode: _manualFocusNode,
                                                  style: const TextStyle(fontFamily: 'Poppins',color: CustomColors.black),
                                                  keyboardType: TextInputType.none,
                                                  decoration: const InputDecoration(
                                                    labelText: 'Enter Cake ID',
                                                    labelStyle: TextStyle(fontFamily: 'Poppins',color: CustomColors.black),
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.all(Radius.circular(9)),
                                                    ),
                                                    focusedBorder: OutlineInputBorder(
                                                      borderSide: BorderSide(color: CustomColors.blueColor, width: 2.0),
                                                      borderRadius: BorderRadius.all(Radius.circular(9)),
                                                    ),
                                                    enabledBorder: OutlineInputBorder(
                                                      borderSide: BorderSide(color: CustomColors.grey, width: 1.5),
                                                      borderRadius: BorderRadius.all(Radius.circular(9)),
                                                    ),
                                                  ),
                                                  enabled: !provider.isQrMode && !provider.isCameraMode,
                                                  onTap: () {
                                                    print(
                                                      'TextField tapped, isQrMode: ${provider.isQrMode}, isCameraMode: ${provider.isCameraMode}',
                                                    );
                                                    if (!provider.isQrMode && !provider.isCameraMode) {
                                                      _manualFocusNode.requestFocus();
                                                      provider.setTextFieldFocused(true);
                                                      print('Requesting focus for manual TextField');
                                                    }
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Consumer<BirthdayCakesProvider>(
                                          builder: (context, provider, _) {
                                            return Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Text('View', style: TextStyle(fontFamily: 'Poppins',fontSize: 12, color: CustomColors.grey)),
                                                Switch(
                                                  value: provider.showExpiry,
                                                  activeColor: CustomColors.redColor,
                                                  onChanged: (_) => provider.toggleDateView(),
                                                  inactiveThumbColor: CustomColors.blueColor,
                                                  inactiveTrackColor: CustomColors.blueColor.withOpacity(0.3),
                                                  trackOutlineColor: MaterialStateProperty.all(CustomColors.whiteColor),
                                                ),
                                                Text(
                                                  provider.showExpiry ? 'Expiry' : 'Received',
                                                  style: const TextStyle(fontFamily: 'Poppins',fontSize: 11, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  Icons.qr_code_scanner,
                                                  size: 32,
                                                  color: provider.isQrMode ? CustomColors.blueColor : CustomColors.grey,
                                                ),
                                                onPressed: _toggleQrMode,
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.camera_alt,
                                                  size: 32,
                                                  color: provider.isCameraMode ? CustomColors.blueColor : CustomColors.grey,
                                                ),
                                                onPressed: _toggleCameraMode,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(right: 25, left: 8),
                                              child: Material(
                                                elevation: 4,
                                                shadowColor: CustomColors.black,
                                                borderRadius: BorderRadius.circular(6),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(7),
                                                    color: CustomColors.blueColor,
                                                  ),
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(8.0),
                                                    child: Row(
                                                      children: [
                                                        const Icon(Icons.cake_rounded, color: CustomColors.whiteColor),
                                                        const SizedBox(width: 4),
                                                        const Text(
                                                          'Total Cakes: ',
                                                          style: TextStyle(fontFamily: 'Poppins',
                                                            fontWeight: FontWeight.w600,
                                                            color: CustomColors.whiteColor,
                                                          ),
                                                        ),
                                                        Text(
                                                          provider.cakes.length.toString(),
                                                          style: TextStyle(fontFamily: 'Poppins',
                                                            fontWeight: FontWeight.w600,
                                                            color: CustomColors.whiteColor,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: provider.isCameraMode
                                        ? MobileScanner(
                                            controller: _scannerController,
                                            onDetect: (BarcodeCapture capture) {
                                              final List<Barcode> barcodes = capture.barcodes;
                                              for (final barcode in barcodes) {
                                                if (_isProcessing) return;
                                                final scannedValue = barcode.rawValue;
                                                if (scannedValue != null && scannedValue.isNotEmpty) {
                                                  _handleInput(scannedValue);
                                                }
                                              }
                                            },
                                          )
                                        : provider.isLoading
                                        ? const Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                CircularProgressIndicator(),
                                                SizedBox(height: 16),
                                                Text("Cakes are Loading..."),
                                              ],
                                            ),
                                          )
                                        : provider.cakes.isEmpty
                                        ? const Center(child: Text("No cakes available"))
                                        : Padding(
                                            padding: const EdgeInsets.only(left: 12, right: 12),
                                            child: CustomScrollView(
                                              controller: _scrollController,
                                              slivers: _buildSliverList(
                                                provider.showExpiry
                                                    ? _groupByExpiry(provider.cakes)
                                                    : _groupByReceived(provider.cakes),
                                              ),
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(flex: 1, child: RepaintBoundary(child: CurrentSaleSection())),
                          ],
                        ),
                      ),
                    ],
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _isAtTopNotifier,
                    builder: (context, isAtTop, _) {
                      return Positioned(
                        bottom: 30,
                        right: 800,
                        child: FloatingActionButton(
                          onPressed: _toggleScrollPosition,
                          backgroundColor: CustomColors.blueColor,
                          elevation: 6,
                          tooltip: isAtTop ? 'Scroll to bottom' : 'Scroll to top',
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              return ScaleTransition(scale: animation, child: child);
                            },
                            child: Icon(
                              isAtTop ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                              key: ValueKey<bool>(isAtTop),
                              size: 28,
                              color: CustomColors.whiteColor,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (provider.isQrMode)
                    Positioned(
                      left: 0,
                      top: 0,
                      width: 1,
                      height: 1,
                      child: TextField(
                        key: const Key('posScannerField'), // for safety
                        focusNode: _qrFocusNode,
                        controller: _qrController,
                        autofocus: true, // auto-focus when QR mode is active
                        showCursor: false,
                        readOnly: true,
                        enableInteractiveSelection: false,
                        decoration: const InputDecoration(border: InputBorder.none),
                        style: const TextStyle(fontFamily: 'Poppins',fontSize: 1, color: Colors.transparent),

                        // ✅ IMPORTANT: allow normal keyboard input (from scanner)
                        keyboardType: TextInputType.text,

                        // ✅ Handles scan completion when Enter key is sent
                        onChanged: (value) {
                          if (value.endsWith('\n') || value.endsWith('\r')) {
                            final scannedValue = value.trim();
                            if (scannedValue.isNotEmpty) {
                              _handleInput(scannedValue);
                            }
                            _qrController.clear();
                            _qrFocusNode.requestFocus(); // refocus for next scan
                          }
                        },

                        onSubmitted: (value) {
                          final scannedValue = value.trim();
                          if (scannedValue.isNotEmpty) {
                            _handleInput(scannedValue);
                          }
                          _qrController.clear();
                          _qrFocusNode.requestFocus(); // refocus again
                        },
                      ),
                    ),

                  if (!provider.isQrMode && !provider.isCameraMode && provider.isTextFieldFocused)
                    Positioned(
                      left: provider.keyboardPosition.dx,
                      top: provider.keyboardPosition.dy,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          provider.updateKeyboardPosition(provider.keyboardPosition + details.delta, MediaQuery.of(context).size);
                        },
                        child: Material(
                          shadowColor: CustomColors.black,
                          child: Container(
                            width: 300,
                            decoration: BoxDecoration(color: CustomColors.whiteColor, borderRadius: BorderRadius.circular(8)),
                            child: NumericKeyboard(
                              focusNode: _manualFocusNode,
                              controller: _manualController,
                              onTextInput: (text) {
                                final currentText = _manualController.text;
                                final newText = currentText + text;
                                _manualController.text = newText;
                                _manualController.selection = TextSelection.collapsed(offset: newText.length);
                                print('Text input: $newText');
                              },
                              onBackspace: () {
                                final currentText = _manualController.text;
                                if (currentText.isNotEmpty) {
                                  final newText = currentText.substring(0, currentText.length - 1);
                                  _manualController.text = newText;
                                  _manualController.selection = TextSelection.collapsed(offset: newText.length);
                                  print('Backspace: $newText');
                                }
                              },
                              onOk: () {
                                print('OK pressed, submitting: ${_manualController.text}');
                                _handleManualAdd(_manualController.text);
                                _manualFocusNode.unfocus();
                                provider.setTextFieldFocused(false);
                              },
                              isLastField: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSliverList(Map<String, List<Map<String, dynamic>>> groupedCakes) {
    List<Widget> slivers = [];

    final dates = groupedCakes.keys.toList();

    for (int dateIndex = 0; dateIndex < dates.length; dateIndex++) {
      final dateKey = dates[dateIndex];
      final date = DateTime.parse(dateKey);
      final formattedDate = DateFormat('dd-MM-yy').format(date);
      final dateCakes = groupedCakes[dateKey]!;
      final totalCakesForDate = dateCakes.fold<int>(0, (sum, group) => sum + (group['count'] as int));

      slivers.add(
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyHeaderDelegate(
            minHeight: 30.0,
            maxHeight: 30.0,
            child: Container(
              color: CustomColors.whiteColor,
              child: Padding(
                padding: const EdgeInsets.only(right: 25, left: 7),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Consumer<BirthdayCakesProvider>(
                          builder: (context, provider, _) {
                            return Row(
                              children: [
                                const Icon(Icons.calendar_month_rounded, size: 17),
                                const SizedBox(width: 8),
                                Text(
                                  "${DateFormat('dd-MM-yy').format(date)} - (${provider.showExpiry ? 'Expiry Date' : 'Received Date'})",
                                  style: const TextStyle(fontFamily: 'Poppins',fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                              ],
                            );
                          },
                        ),
                        Row(
                          children: [
                            const Icon(Icons.cake_sharp, size: 17),
                            Text(" $totalCakesForDate", style: const TextStyle(fontFamily: 'Poppins',fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      slivers.add(
        SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 170.0,
            mainAxisSpacing: 12.0,
            crossAxisSpacing: 25,
            childAspectRatio: 140 / 120,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final cakeGroup = dateCakes[index];
            return SizedBox(
              width: 160,
              height: 120,
              child: GestureDetector(
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      alignment: Alignment.centerLeft,
                      backgroundColor: CustomColors.whiteColor,
                      title: Material(
                        shadowColor: CustomColors.black,
                        borderRadius: BorderRadius.circular(12),
                        elevation: 4,
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(color: CustomColors.blueColor, borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    cakeGroup['varianceName'],
                                    style: TextStyle(fontFamily: 'Poppins',color: CustomColors.whiteColor, fontSize: 20, fontWeight: FontWeight.w400),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      content: SizedBox(
                        width: 700,
                        child: GridView.builder(
                          shrinkWrap: true,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 2),
                          itemCount: cakeGroup['cakes'].length,
                          itemBuilder: (context, index) {
                            final cake = cakeGroup['cakes'][index];
                            final expiryDate = cake.expiryDate.toLocal();
                            final now = DateTime.now();
                            final nowDate = DateTime(now.year, now.month, now.day);
                            final expiryDateOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
                            final daysRemaining = expiryDateOnly.difference(nowDate).inDays;
                            DateTime d = cake.expiryDate.toLocal();

                            final formatter = DateFormat('dd-MM-yy');
                            String formatted = formatter.format(d);

                            String expiryText;
                            Color badgeColor;
                            if (daysRemaining > 0) {
                              expiryText = '$daysRemaining DAYS LEFT';
                              badgeColor = Colors.green;
                            } else if (daysRemaining == 0) {
                              expiryText = 'EXPIRING TODAY';
                              badgeColor = Colors.orange;
                            } else {
                              expiryText = 'EXPIRED';
                              badgeColor = CustomColors.redColor;
                            }
                            return Card(
                              color: CustomColors.whiteColor,
                              elevation: 4,
                              shadowColor: CustomColors.black,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Row(
                                      children: [
                                        const Text('QR CODE: ', style: TextStyle(fontFamily: 'Poppins',fontWeight: FontWeight.bold)),
                                        Text('${cake.cakeId}'),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        const Text('Expiry Date:', style: TextStyle(fontFamily: 'Poppins',fontWeight: FontWeight.bold)),
                                        Text(' $formatted'),
                                      ],
                                    ),
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(12)),
                                      child: Text(
                                        expiryText,
                                        style: const TextStyle(fontFamily: 'Poppins',
                                          color: CustomColors.whiteColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 160,
                          height: 115,
                          decoration: BoxDecoration(
                            color: CustomColors.whiteColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: CustomColors.grey.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 80,
                                width: 160,
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(12),
                                    topLeft: Radius.circular(12),
                                  ),
                                  child: Image.asset(
                                    "assets/cakes.png",
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      color: CustomColors.grey.withOpacity(0.2),
                                      child: const Icon(Icons.cake, color: CustomColors.grey, size: 50),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4, left: 2, right: 2),
                                  child: Text(
                                    cakeGroup['varianceName'],
                                    style: const TextStyle(fontFamily: 'Poppins',fontSize: 11, fontWeight: FontWeight.w600),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (cakeGroup['count'] > 1)
                      Positioned(
                        top: 0,
                        right: 5,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: CustomColors.redColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: CustomColors.whiteColor, width: 2),
                          ),
                          child: Text(
                            '${cakeGroup['count']}',
                            style: const TextStyle(fontFamily: 'Poppins',color: CustomColors.whiteColor, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }, childCount: dateCakes.length),
        ),
      );

      if (dateIndex < dates.length - 1) {
        slivers.add(
          SliverToBoxAdapter(
            child: Divider(height: 1, thickness: 1, color: CustomColors.grey.withOpacity(0.2), indent: 20, endIndent: 20),
          ),
        );
      }
    }

    return slivers;
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _StickyHeaderDelegate({required this.minHeight, required this.maxHeight, required this.child});

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight || minHeight != oldDelegate.minHeight || child != oldDelegate.child;
  }
}
