class EventModel {
  final String eventId;
  final String eventName;
  final String status;

  EventModel({
    required this.eventId,
    required this.eventName,
    required this.status,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      eventId: json["eventId"],
      eventName: json["eventname"],
      status: json["status"],
    );
  }
}
