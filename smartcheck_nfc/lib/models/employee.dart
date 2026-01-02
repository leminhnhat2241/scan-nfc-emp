class Employee {
  final String employeeId;
  final String name;
  final String? department;
  final String? position;
  // Bổ sung cho nâng cấp
  final String? email; // Email để gửi báo cáo
  final double? salaryRate; // Lương theo giờ
  final bool isActive; // Trạng thái: true (đang làm), false (đã nghỉ/khóa)

  Employee({
    required this.employeeId,
    required this.name,
    this.department,
    this.position,
    this.email,
    this.salaryRate,
    this.isActive = true, // Mặc định là đang hoạt động
  });

  // Chuyển đổi từ Map sang Employee
  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      employeeId: map['employee_id'] as String,
      name: map['name'] as String,
      department: map['department'] as String?,
      position: map['position'] as String?,
      // Map các trường mới, xử lý null safety
      email: map['email'] as String?,
      salaryRate: map['salary_rate'] != null ? (map['salary_rate'] as num).toDouble() : null,
      isActive: map['is_active'] == null ? true : (map['is_active'] == 1),
    );
  }

  // Chuyển đổi từ Employee sang Map
  Map<String, dynamic> toMap() {
    return {
      'employee_id': employeeId,
      'name': name,
      'department': department,
      'position': position,
      // Map các trường mới
      'email': email,
      'salary_rate': salaryRate,
      'is_active': isActive ? 1 : 0,
    };
  }

  // Chuyển đổi từ JSON string sang Employee
  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      employeeId: json['employee_id'] as String,
      name: json['name'] as String,
      department: json['department'] as String?,
      position: json['position'] as String?,
      email: json['email'] as String?,
      salaryRate: json['salary_rate'] != null ? (json['salary_rate'] as num).toDouble() : null,
      isActive: json['is_active'] == null ? true : (json['is_active'] == 1),
    );
  }

  // Chuyển đổi từ Employee sang JSON
  Map<String, dynamic> toJson() {
    return {
      'employee_id': employeeId,
      'name': name,
      'department': department,
      'position': position,
      'email': email,
      'salary_rate': salaryRate,
      'is_active': isActive ? 1 : 0,
    };
  }

  @override
  String toString() {
    return 'Employee{employeeId: $employeeId, name: $name, dept: $department, email: $email, active: $isActive}';
  }
}
