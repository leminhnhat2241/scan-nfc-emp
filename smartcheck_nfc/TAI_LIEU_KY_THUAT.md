# 📚 TÀI LIỆU KỸ THUẬT

## Kiến trúc ứng dụng

```
SmartCheck NFC App
│
├── Presentation Layer (UI)
│   ├── HomeScreen - Màn hình chính + quét NFC
│   ├── WriteNfcScreen - Ghi thẻ NFC
│   └── EmployeeListScreen - Danh sách nhân viên
│
├── Business Logic Layer
│   ├── NfcService - Xử lý đọc/ghi NFC
│   └── DatabaseHelper - Quản lý SQLite
│
└── Data Layer
    ├── Employee Model
    └── Attendance Model
```

## Chi tiết các thành phần

### 1. Models

#### `Employee` (lib/models/employee.dart)

```dart
class Employee {
  final String employeeId;    // Mã nhân viên (PK)
  final String name;           // Tên nhân viên
  final String? department;    // Phòng ban (optional)
  final String? position;      // Chức vụ (optional)
}
```

**Chức năng:**

- Lưu trữ thông tin nhân viên
- Chuyển đổi giữa Object ↔ Map ↔ JSON
- Dùng để ghi lên thẻ NFC

#### `Attendance` (lib/models/attendance.dart)

```dart
class Attendance {
  final int? id;                 // ID tự động tăng
  final String employeeId;       // Mã nhân viên (FK)
  final String employeeName;     // Tên nhân viên
  final DateTime checkInTime;    // Thời gian điểm danh
  final String status;           // Trạng thái: "Đi làm" / "Đi muộn"
}
```

**Chức năng:**

- Lưu lịch sử điểm danh
- Format hiển thị thời gian
- Tính toán trạng thái

### 2. Services

#### `DatabaseHelper` (lib/services/database_helper.dart)

**Database Schema:**

```sql
-- Bảng employees
CREATE TABLE employees (
  employee_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  department TEXT,
  position TEXT
);

-- Bảng attendance
CREATE TABLE attendance (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  employee_id TEXT NOT NULL,
  employee_name TEXT NOT NULL,
  check_in_time TEXT NOT NULL,
  status TEXT NOT NULL,
  FOREIGN KEY (employee_id) REFERENCES employees (employee_id)
);
```

**API Methods:**

**Employee Management:**

- `insertEmployee(Employee)` - Thêm nhân viên
- `getAllEmployees()` - Lấy tất cả nhân viên
- `getEmployeeById(String)` - Tìm nhân viên theo ID
- `updateEmployee(Employee)` - Cập nhật nhân viên
- `deleteEmployee(String)` - Xóa nhân viên

**Attendance Management:**

- `insertAttendance(Attendance)` - Thêm bản ghi điểm danh
- `getAllAttendance()` - Lấy tất cả điểm danh
- `getAttendanceByDate(DateTime)` - Lấy điểm danh theo ngày
- `getAttendanceByEmployeeAndDate(String, DateTime)` - Lấy điểm danh cụ thể
- `hasCheckedInToday(String)` - Kiểm tra đã điểm danh chưa

#### `NfcService` (lib/services/nfc_service.dart)

**Chức năng chính:**

1. **isNfcAvailable()** - Kiểm tra NFC có sẵn không

   ```dart
   final available = await nfcService.isNfcAvailable();
   ```

2. **readNfcTag()** - Đọc dữ liệu từ thẻ NFC

   ```dart
   final employee = await nfcService.readNfcTag();
   // Trả về: Employee? (null nếu lỗi)
   ```

   **Quy trình đọc:**

   - Bật NFC session
   - Phát hiện thẻ
   - Đọc NDEF records
   - Parse JSON → Employee object
   - Dừng session

3. **writeNfcTag(Employee)** - Ghi dữ liệu lên thẻ NFC

   ```dart
   final success = await nfcService.writeNfcTag(employee);
   // Trả về: bool (true nếu thành công)
   ```

   **Quy trình ghi:**

   - Bật NFC session
   - Phát hiện thẻ
   - Kiểm tra thẻ có thể ghi không
   - Employee → JSON → NDEF message
   - Ghi vào thẻ
   - Dừng session

**Định dạng dữ liệu trên thẻ NFC:**

```json
{
  "employee_id": "EMP032",
  "name": "Nguyễn Văn A",
  "department": "Kỹ thuật",
  "position": "Lập trình viên"
}
```

### 3. Screens

#### `HomeScreen` (lib/screens/home_screen.dart)

**Chức năng:**

- Hiển thị danh sách điểm danh hôm nay
- Nút quét NFC để điểm danh
- Thống kê số người đã điểm danh
- Navigation đến các màn hình khác

**Luồng điểm danh:**

```
1. User nhấn "QUÉT THẺ NFC"
2. Hiển thị thông báo "Đưa thẻ đến điện thoại..."
3. Đọc thẻ NFC → lấy Employee
4. Kiểm tra Employee có trong DB không
5. Kiểm tra đã điểm danh hôm nay chưa
6. Tính toán status (Đi làm/Đi muộn)
7. Lưu Attendance vào DB
8. Hiển thị dialog thành công
9. Reload danh sách
```

**Quy tắc trạng thái:**

- Trước 8:30 → "Đi làm"
- Sau 8:30 → "Đi muộn"

#### `WriteNfcScreen` (lib/screens/write_nfc_screen.dart)

**Chức năng:**

- Form nhập thông tin nhân viên
- Validation dữ liệu
- Ghi vào thẻ NFC
- Lưu vào database

**Luồng ghi thẻ:**

```
1. User nhập thông tin
2. Validate form
3. Tạo Employee object
4. Lưu vào database
5. Ghi vào thẻ NFC
6. Hiển thị kết quả
7. Clear form
```

#### `EmployeeListScreen` (lib/screens/employee_list_screen.dart)

**Chức năng:**

- Hiển thị danh sách tất cả nhân viên
- Hiển thị trạng thái điểm danh hôm nay
- Thống kê (Tổng số / Đã điểm danh / Chưa điểm danh)
- Xem chi tiết nhân viên
- Xem lịch sử điểm danh 7 ngày
- Xóa nhân viên

**State Management:**

```dart
List<Employee> _employees
Map<String, bool> _attendanceStatus
bool _isLoading
```

## Xử lý lỗi

### NFC Errors

```dart
try {
  final employee = await nfcService.readNfcTag();
  if (employee == null) {
    // Xử lý: không đọc được thẻ
  }
} catch (e) {
  // Xử lý: lỗi NFC exception
}
```

### Database Errors

```dart
try {
  await dbHelper.insertAttendance(attendance);
} catch (e) {
  // Xử lý: lỗi database
}
```

## Performance

### Optimization Tips

1. **Database:**

   - Sử dụng index trên `employee_id`
   - Query theo ngày để giảm số bản ghi

2. **NFC:**

   - Timeout 5 giây cho mỗi session
   - Stop session ngay sau khi hoàn thành

3. **UI:**
   - Sử dụng `FutureBuilder` cho async data
   - `RefreshIndicator` cho pull-to-refresh
   - `CircularProgressIndicator` khi loading

## Testing

### Unit Tests (Nên thêm)

```dart
test('Kiểm tra tính status điểm danh', () {
  final time1 = DateTime(2024, 1, 1, 8, 0);  // 8:00
  expect(getAttendanceStatus(time1), 'Đi làm');

  final time2 = DateTime(2024, 1, 1, 9, 0);  // 9:00
  expect(getAttendanceStatus(time2), 'Đi muộn');
});
```

### Widget Tests (Nên thêm)

```dart
testWidgets('Hiển thị nút quét NFC', (tester) async {
  await tester.pumpWidget(MyApp());
  expect(find.text('QUÉT THẺ NFC'), findsOneWidget);
});
```

## Security Considerations

1. **Database:**

   - Dữ liệu lưu local, không có mã hóa
   - Cân nhắc thêm sqlcipher nếu cần bảo mật cao

2. **NFC:**

   - Dữ liệu trên thẻ là plaintext JSON
   - Có thể bị đọc bởi bất kỳ app NFC nào
   - Cân nhắc thêm chữ ký số nếu cần

3. **Permissions:**
   - Android: NFC permission
   - iOS: NFC capability + usage description

## Future Enhancements

### Gợi ý cải tiến:

1. **Cloud Sync**

   - Firebase Firestore để đồng bộ
   - Real-time updates
   - Backup tự động

2. **Reports**

   - Xuất Excel/PDF
   - Thống kê theo tháng
   - Biểu đồ attendance rate

3. **Notifications**

   - Push notification khi có điểm danh
   - Nhắc nhở nhân viên chưa điểm danh
   - Email report hàng ngày

4. **Advanced Features**

   - Face recognition kết hợp NFC
   - GPS check-in location
   - QR code backup (nếu không có NFC)
   - Quản lý ca làm việc
   - Tính công tự động

5. **Admin Panel**
   - Web dashboard
   - Quản lý nhiều công ty
   - Role-based access control

## Dependencies Version

```yaml
nfc_manager: ^3.5.0 # NFC read/write
sqflite: ^2.3.0 # SQLite database
path: ^1.9.0 # Path manipulation
intl: ^0.19.0 # Date formatting
shared_preferences: ^2.2.2 # Simple storage
```

## Troubleshooting

### iOS NFC không hoạt động

- Kiểm tra Info.plist có NFCReaderUsageDescription
- Kiểm tra entitlements có NFC capability
- Chỉ iPhone 7+ mới có NFC

### Android NFC không hoạt động

- Kiểm tra AndroidManifest.xml có NFC permission
- Bật NFC trong Settings
- Thử vị trí khác trên mặt sau điện thoại

### Database lỗi

- Xóa app và cài lại
- Check database path
- Check write permissions

---

**Tài liệu này sẽ được cập nhật khi có thay đổi.**
