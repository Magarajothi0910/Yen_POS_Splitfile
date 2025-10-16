
class Branch {
  final String? branchId;
  final String branchName;
  final String aliasName;

  Branch({
    required this.branchId,
    required this.branchName,
    required this.aliasName,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      branchId: json['branchId'] ?? '', // Null-safe with default value
      branchName: json['branchName'] ?? '',
      aliasName: json['aliasName'] ?? '',
    );
  }

  // Convert Branch object to Map for Hive storage
  Map<String, dynamic> toMap() {
    return {
      'branchId': branchId,
      'branchName': branchName,
      'aliasName': aliasName,
    };
  }

  // Create a Branch object from a Hive-stored Map
  factory Branch.fromMap(Map<String, dynamic> map) {
    return Branch(
      branchId: map['branchId'] ?? '', // Null-safe with default value
      branchName: map['branchName'] ?? '',
      aliasName: map['aliasName'] ?? '',
    );
  }
}