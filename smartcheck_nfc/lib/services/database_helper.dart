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
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Thêm cột image_path vào bảng attendance
      await db.execute('''
        ALTER TABLE attendance ADD COLUMN image_path TEXT
      ''');
      print('✅ Database upgraded: Đã thêm cột image_path');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // Bảng nhân viên
    await db.execute('''
      CREATE TABLE employees (
        employee_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        department TEXT,
        position TEXT
      )
    ''');

    // Bảng điểm danh
    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id TEXT NOT NULL,
        employee_name TEXT NOT NULL,
        check_in_time TEXT NOT NULL,
        status TEXT NOT NULL,
        image_path TEXT,
        FOREIGN KEY (employee_id) REFERENCES employees (employee_id)
      )
    ''');

    // Thêm một số nhân viên mẫu
    await db.insert('employees', {
      'employee_id': 'EMP001',
      'name': 'Nguyễn Văn A',
      'department': 'Kỹ thuật',
      'position': 'Lập trình viên',
    });

    await db.insert('employees', {
      'employee_id': 'EMP002',
      'name': 'Trần Thị B',
      'department': 'Nhân sự',
      'position': 'Trưởng phòng',
    });

    await db.insert('employees', {
      'employee_id': 'EMP003',
      'name': 'Lê Văn C',
      'department': 'Kỹ thuật',
      'position': 'Tester',
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

  // Lấy tất cả nhân viên
  Future<List<Employee>> getAllEmployees() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('employees');
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

  // Xóa nhân viên
  Future<void> deleteEmployee(String employeeId) async {
    final db = await database;
    await db.delete(
      'employees',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
    );
  }

  // === QUẢN LÝ ĐIỂM DANH ===

  // Thêm bản ghi điểm danh
  Future<int> insertAttendance(Attendance attendance) async {
    final db = await database;
    return await db.insert(
      'attendance',
      attendance.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
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

  // Lấy điểm danh của nhân viên theo ngày
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
