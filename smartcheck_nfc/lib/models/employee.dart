class Employee {
  final String employeeId;
  final String name;
  final String? department;
  final String? position;

  Employee({
    required this.employeeId,
    required this.name,
    this.department,
    this.position,
  });

  // Chuyển đổi từ Map sang Employee
  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      employeeId: map['employee_id'] as String,
      name: map['name'] as String,
      department: map['department'] as String?,
      position: map['position'] as String?,
    );
  }

  // Chuyển đổi từ Employee sang Map
  Map<String, dynamic> toMap() {
    return {
      'employee_id': employeeId,
      'name': name,
      'department': department,
      'position': position,
    };
  }

  // Chuyển đổi từ JSON string sang Employee
  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      employeeId: json['employee_id'] as String,
      name: json['name'] as String,
      department: json['department'] as String?,
      position: json['position'] as String?,
    );
  }

  // Chuyển đổi từ Employee sang JSON
  Map<String, dynamic> toJson() {
    return {
      'employee_id': employeeId,
      'name': name,
      'department': department,
      'position': position,
    };
  }

  @override
  String toString() {
    return 'Employee{employeeId: $employeeId, name: $name, department: $department, position: $position}';
  }
}
