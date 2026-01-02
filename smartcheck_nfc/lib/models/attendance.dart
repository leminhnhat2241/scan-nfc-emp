class Attendance {
  final int? id;
  final String employeeId;
  final String employeeName;
  final DateTime checkInTime;
  final String status; // "Đi làm", "Đi muộn", "Về sớm"
  final String? imagePath; // Đường dẫn ảnh chụp tự động (Anti-Fraud)
  
  // Bổ sung cho nâng cấp Check-out và Tính lương
  final DateTime? checkOutTime; // Thời gian về
  final double? workHours; // Số giờ làm việc (đã trừ nghỉ trưa nếu cần)

  Attendance({
    this.id,
    required this.employeeId,
    required this.employeeName,
    required this.checkInTime,
    this.status = "Đi làm",
    this.imagePath,
    this.checkOutTime,
    this.workHours,
  });

  // Chuyển đổi từ Map sang Attendance
  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'] as int?,
      employeeId: map['employee_id'] as String,
      employeeName: map['employee_name'] as String,
      checkInTime: DateTime.parse(map['check_in_time'] as String),
      status: map['status'] as String? ?? "Đi làm",
      imagePath: map['image_path'] as String?,
      // Map các trường mới
      checkOutTime: map['check_out_time'] != null ? DateTime.parse(map['check_out_time'] as String) : null,
      workHours: map['work_hours'] != null ? (map['work_hours'] as num).toDouble() : null,
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
      'image_path': imagePath,
      // Map các trường mới
      'check_out_time': checkOutTime?.toIso8601String(),
      'work_hours': workHours,
    };
  }

  // Format thời gian hiển thị
  String getFormattedTime() {
    return '${checkInTime.hour.toString().padLeft(2, '0')}:${checkInTime.minute.toString().padLeft(2, '0')}';
  }
  
  String getFormattedOutTime() {
    if (checkOutTime == null) return "--:--";
    return '${checkOutTime!.hour.toString().padLeft(2, '0')}:${checkOutTime!.minute.toString().padLeft(2, '0')}';
  }

  String getFormattedDate() {
    return '${checkInTime.day}/${checkInTime.month}/${checkInTime.year}';
  }

  @override
  String toString() {
    return 'Attendance{id: $id, employeeId: $employeeId, in: $checkInTime, out: $checkOutTime, hours: $workHours}';
  }
}
