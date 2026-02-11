import 'package:meta/meta.dart';
import 'dart:convert';

BirthDayCake birthDayCakeFromJson(String str) => BirthDayCake.fromJson(json.decode(str));

String birthDayCakeToJson(BirthDayCake data) => json.encode(data.toJson());

class BirthDayCake {
  final String id;
  final String cakeId;
  final String varianceName;
  final String branchName;
  final int selfLife;
  final DateTime productionDate;
  final DateTime expiryDate;
  final String status;
  final String itemCode;
  final String manufacture;
  final DateTime recievedDate;

  BirthDayCake({
    required this.id,
    required this.cakeId,
    required this.varianceName,
    required this.branchName,
    required this.selfLife,
    required this.productionDate,
    required this.expiryDate,
    required this.status,
    required this.itemCode,
    required this.manufacture,
    required this.recievedDate,
  });

  factory BirthDayCake.fromJson(Map<String, dynamic> json) => BirthDayCake(
    id: json["id"],
    cakeId: json["cakeId"],
    varianceName: json["varianceName"],
    branchName: json["branchName"],
    selfLife: json["selfLife"],
    productionDate: DateTime.parse(json["productionDate"]),
    expiryDate: DateTime.parse(json["expiryDate"]),
    status: json["status"],
    itemCode: json["itemCode"],
    manufacture: json["manufacture"],
    recievedDate: DateTime.parse(json["recievedDate"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "cakeId": cakeId,
    "varianceName": varianceName,
    "branchName": branchName,
    "selfLife": selfLife,
    "productionDate": productionDate.toIso8601String(),
    "expiryDate": expiryDate.toIso8601String(),
    "status": status,
    "itemCode": itemCode,
    "manufacture": manufacture,
    "recievedDate": recievedDate.toIso8601String,
  };
}
