import 'package:flutter/material.dart';

const branchName = "Aranmanai";
const String deviceId = "2";
const String deviceNumber = "1";
bool sentServer = false;
final shiftId = ValueNotifier<String>("");
final dayEndStatus = ValueNotifier<String>("");
final status = ValueNotifier<String>("");

List<Map<String, String>> dayEndData = [];

const empId = "1234";


final dispatchStatus = ValueNotifier<String>("");
final itemTransferStatus = ValueNotifier<String>("");
final soApprovalStatus = ValueNotifier<String>("");
final storeStatus = ValueNotifier<String>("");
final soDeliveryStatus = ValueNotifier<String>("");
final shiftOpenStatus = ValueNotifier<String>("");
