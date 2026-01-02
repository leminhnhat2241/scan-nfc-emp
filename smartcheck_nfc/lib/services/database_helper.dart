import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/employee.dart';
import '../models/attendance.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('smartcheck.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3, // Nâng version lên 3
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        ALTER TABLE attendance ADD COLUMN image_path TEXT
      ''');
    }
    
    // Nâng cấp version 3: Thêm Check-out và Lương
    if (oldVersion < 3) {
      // Bảng employees: Thêm email, salary_rate, is_active
      await db.execute('ALTER TABLE employees ADD COLUMN email TEXT');
      await db.execute('ALTER TABLE employees ADD COLUMN salary_rate REAL');
      await db.execute('ALTER TABLE employees ADD COLUMN is_active INTEGER DEFAULT 1');

      // Bảng attendance: Thêm check_out_time, work_hours
      await db.execute('ALTER TABLE attendance ADD COLUMN check_out_time TEXT');
      await db.execute('ALTER TABLE attendance ADD COLUMN work_hours REAL');
      
      print('✅ Database upgraded to v3: Added salary & email fields');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // Bảng nhân viên (Full schema v3)
    await db.execute('''
      CREATE TABLE employees (
        employee_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        department TEXT,
        position TEXT,
        email TEXT,
        salary_rate REAL,
        is_active INTEGER DEFAULT 1
      )
    ''');

    // Bảng điểm danh (Full schema v3)
    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id TEXT NOT NULL,
        employee_name TEXT NOT NULL,
        check_in_time TEXT NOT NULL,
        status TEXT NOT NULL,
        image_path TEXT,
        check_out_time TEXT,
        work_hours REAL,
        FOREIGN KEY (employee_id) REFERENCES employees (employee_id)
      )
    ''');

    // Dữ liệu mẫu
    await db.insert('employees', {
      'employee_id': 'EMP001',
      'name': 'Nguyễn Văn A',
      'department': 'Kỹ thuật',
      'position': 'Lập trình viên',
      'email': 'nv.a@example.com',
      'salary_rate': 50000.0,
      'is_active': 1
    });

    await db.insert('employees', {
      'employee_id': 'EMP002',
      'name': 'Trần Thị B',
      'department': 'Nhân sự',
      'position': 'Trưởng phòng',
      'email': 'tt.b@example.com',
      'salary_rate': 70000.0,
      'is_active': 1
    });
  }

  // === QUẢN LÝ NHÂN VIÊN ===

  // Thêm nhân viên mới
  Future<void> insertEmployee(Employee employee) async {
    final db = await database;
    await db.insert(
      'employees',
      employee.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Lấy tất cả nhân viên (mặc định lấy cả người đã nghỉ)
  Future<List<Employee>> getAllEmployees({bool activeOnly = false}) async {
    final db = await database;
    final whereClause = activeOnly ? 'is_active = 1' : null;
    final List<Map<String, dynamic>> maps = await db.query(
      'employees', 
      where: whereClause
    );
    return List.generate(maps.length, (i) => Employee.fromMap(maps[i]));
  }

  // Lấy nhân viên theo ID
  Future<Employee?> getEmployeeById(String employeeId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'employees',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
    );

    if (maps.isEmpty) return null;
    return Employee.fromMap(maps.first);
  }

  // Cập nhật nhân viên
  Future<void> updateEmployee(Employee employee) async {
    final db = await database;
    await db.update(
      'employees',
      employee.toMap(),
      where: 'employee_id = ?',
      whereArgs: [employee.employeeId],
    );
  }
  
  // Khóa/Mở khóa nhân viên (Soft Delete)
  Future<void> toggleEmployeeStatus(String employeeId, bool isActive) async {
    final db = await database;
    await db.update(
      'employees',
      {'is_active': isActive ? 1 : 0},
      where: 'employee_id = ?',
      whereArgs: [employeeId],
    );
  }

  // Xóa nhân viên (Hard Delete - Chỉ dùng khi cần thiết)
  Future<void> deleteEmployee(String employeeId) async {
    final db = await database;
    await db.delete(
      'employees',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
    );
  }

  // === QUẢN LÝ ĐIỂM DANH ===

  // Thêm bản ghi điểm danh (Check-in)
  Future<int> insertAttendance(Attendance attendance) async {
    final db = await database;
    return await db.insert(
      'attendance',
      attendance.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  // Cập nhật bản ghi điểm danh (Dùng cho Check-out hoặc Admin sửa)
  Future<void> updateAttendance(Attendance attendance) async {
    final db = await database;
    await db.update(
      'attendance',
      attendance.toMap(),
      where: 'id = ?',
      whereArgs: [attendance.id],
    );
  }

  // Lấy tất cả bản ghi điểm danh
  Future<List<Attendance>> getAllAttendance() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      orderBy: 'check_in_time DESC',
    );
    return List.generate(maps.length, (i) => Attendance.fromMap(maps[i]));
  }

  // Lấy điểm danh theo ngày
  Future<List<Attendance>> getAttendanceByDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      where: 'check_in_time >= ? AND check_in_time <= ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'check_in_time DESC',
    );
    return List.generate(maps.length, (i) => Attendance.fromMap(maps[i]));
  }
  
  // Lấy điểm danh theo khoảng thời gian (cho Báo cáo)
  Future<List<Attendance>> getAttendanceByRange(DateTime start, DateTime end) async {
    final db = await database;
    // Đảm bảo lấy trọn vẹn ngày
    final startTime = DateTime(start.year, start.month, start.day);
    final endTime = DateTime(end.year, end.month, end.day, 23, 59, 59);
    
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      where: 'check_in_time >= ? AND check_in_time <= ?',
      whereArgs: [startTime.toIso8601String(), endTime.toIso8601String()],
      orderBy: 'check_in_time ASC',
    );
    return List.generate(maps.length, (i) => Attendance.fromMap(maps[i]));
  }

  // Lấy điểm danh của nhân viên theo ngày (để check trùng hoặc check-out)
  Future<Attendance?> getAttendanceByEmployeeAndDate(
    String employeeId,
    DateTime date,
  ) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      where: 'employee_id = ? AND check_in_time >= ? AND check_in_time <= ?',
      whereArgs: [
        employeeId,
        startOfDay.toIso8601String(),
        endOfDay.toIso8601String(),
      ],
    );

    if (maps.isEmpty) return null;
    return Attendance.fromMap(maps.first);
  }

  // Kiểm tra nhân viên đã điểm danh hôm nay chưa
  Future<bool> hasCheckedInToday(String employeeId) async {
    final attendance = await getAttendanceByEmployeeAndDate(
      employeeId,
      DateTime.now(),
    );
    return attendance != null;
  }

  // Xóa bản ghi điểm danh
  Future<void> deleteAttendance(int id) async {
    final db = await database;
    await db.delete('attendance', where: 'id = ?', whereArgs: [id]);
  }

  // Xóa tất cả điểm danh
  Future<void> deleteAllAttendance() async {
    final db = await database;
    await db.delete('attendance');
  }

  // Đóng database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
