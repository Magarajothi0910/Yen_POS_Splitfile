class ApprovalOrderDetail {
  String? approvalStatus;
  final String summary;
  final String? approvalDate;
  final String? approvedBy;
  final String? approvalType;

  ApprovalOrderDetail({
    this.approvalStatus,
    required this.summary,
    this.approvalDate,
    this.approvedBy,
    this.approvalType,
  });

  /// Factory method to create an instance from a JSON map
  factory ApprovalOrderDetail.fromJson(Map<String, dynamic> json) {
    return ApprovalOrderDetail(
      approvalStatus: json['approvalStatus'] ?? '',
      approvalType: json['approvalType'] ?? '',
      summary: json['summary'] ?? '',
      approvalDate: json['approvalDate'] ?? 'N/A',
      approvedBy: json['approvedBy'] ?? 'N/A',
    );
  }

  /// Convert the object to JSON format
  Map<String, dynamic> toJson() {
    return {
      'approvalStatus': approvalStatus,
      'summary': summary,
      'approvalDate': approvalDate,
      'approvedBy': approvedBy,
      'approvalType': approvalType,
    };
  }
}
