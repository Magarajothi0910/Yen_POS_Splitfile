class EventModel {
  final String chargeId;
  final String chargeType;
  final String status;

  EventModel({
    required this.chargeId,
    required this.chargeType,
    required this.status,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      chargeId: json["chargeId"],
      chargeType: json["chargeType"],
      status: json["status"],
    );
  }
}
