
class Employee {
  final String employeeNumber;
  final String firstName;
  final String? lastName;
  final String position;

  Employee({
    required this.employeeNumber,
    required this.firstName,
    this.lastName,
    required this.position,
  });

  Map<String, dynamic> toJson() {
    return {
      'employeeNumber': employeeNumber,
      'firstName': firstName,
      'lastName': lastName,
      'position': position,
    };
  }

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      employeeNumber: json['employeeNumber'],
      firstName: json['firstName'],
      lastName: json['lastname'],
      position: json['position'],
    );
  }
}
