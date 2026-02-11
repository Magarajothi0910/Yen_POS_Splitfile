class EventModel {
  final String deliveryTypeId;
  final String deliveryType;
  final String status;

  EventModel({
    required this.deliveryTypeId,
    required this.deliveryType,
    required this.status,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      deliveryTypeId: json["deliveryTypeId"],
      deliveryType: json["deliveryType"],
      status: json["status"],
    );
  }
}
