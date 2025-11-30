class Attendance {
  final int? id;
  final String employeeId;
  final String employeeName;
  final DateTime checkInTime;
  final String status; // "Đi làm", "Đi muộn", "Về sớm"

  Attendance({
    this.id,
    required this.employeeId,
    required this.employeeName,
    required this.checkInTime,
    this.status = "Đi làm",
  });

  // Chuyển đổi từ Map sang Attendance
  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'] as int?,
      employeeId: map['employee_id'] as String,
      employeeName: map['employee_name'] as String,
      checkInTime: DateTime.parse(map['check_in_time'] as String),
      status: map['status'] as String? ?? "Đi làm",
    );
  }

  // Chuyển đổi từ Attendance sang Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'check_in_time': checkInTime.toIso8601String(),
      'status': status,
    };
  }

  // Format thời gian hiển thị
  String getFormattedTime() {
    return '${checkInTime.hour.toString().padLeft(2, '0')}:${checkInTime.minute.toString().padLeft(2, '0')}';
  }

  String getFormattedDate() {
    return '${checkInTime.day}/${checkInTime.month}/${checkInTime.year}';
  }

  @override
  String toString() {
    return 'Attendance{id: $id, employeeId: $employeeId, employeeName: $employeeName, checkInTime: $checkInTime, status: $status}';
  }
}
