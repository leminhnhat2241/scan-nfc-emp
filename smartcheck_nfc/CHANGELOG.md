# CHANGELOG

Tất cả những thay đổi quan trọng của dự án sẽ được ghi lại ở đây.

## [1.0.0] - 2024-12-01

### ✨ Tính năng mới

#### Core Features

- ✅ Ghi thẻ NFC cho nhân viên với thông tin đầy đủ
- ✅ Điểm danh nhân viên bằng cách quét thẻ NFC
- ✅ Quản lý danh sách nhân viên
- ✅ Xem lịch sử điểm danh theo ngày
- ✅ Thống kê số người đã/chưa điểm danh

#### Màn hình

- ✅ **Home Screen**: Màn hình chính với danh sách điểm danh hôm nay
- ✅ **Write NFC Screen**: Màn hình ghi thẻ NFC cho nhân viên mới
- ✅ **Employee List Screen**: Danh sách tất cả nhân viên với trạng thái

#### Database

- ✅ SQLite local database
- ✅ Bảng `employees` để lưu thông tin nhân viên
- ✅ Bảng `attendance` để lưu lịch sử điểm danh
- ✅ Dữ liệu mẫu ban đầu (3 nhân viên)

#### NFC Features

- ✅ Đọc thẻ NFC (NDEF format)
- ✅ Ghi thẻ NFC với JSON data
- ✅ Kiểm tra NFC availability
- ✅ Error handling cho NFC operations

#### Business Logic

- ✅ Tự động phân loại trạng thái (Đi làm/Đi muộn)
- ✅ Ngăn điểm danh trùng lặp (1 lần/ngày)
- ✅ Kiểm tra nhân viên tồn tại trước khi điểm danh
- ✅ Tính toán thời gian điểm danh

#### UI/UX

- ✅ Material Design 3
- ✅ Responsive layout
- ✅ Loading indicators
- ✅ Success/Error dialogs
- ✅ Snackbar notifications
- ✅ Pull-to-refresh
- ✅ Icon navigation
- ✅ Floating action buttons

#### Localization

- ✅ Hỗ trợ tiếng Việt
- ✅ Format ngày tháng tiếng Việt
- ✅ Vietnamese text throughout app

### 🔧 Technical

- ✅ Flutter SDK 3.10.1+
- ✅ Android 5.0+ support
- ✅ iOS 11.0+ support
- ✅ NFC Manager 3.5.0
- ✅ SQLite 2.3.0
- ✅ Clean architecture pattern

### 📱 Platform Support

#### Android

- ✅ NFC permissions trong AndroidManifest.xml
- ✅ Hardware feature declaration
- ✅ Tested trên Android 5.0+

#### iOS

- ✅ NFC capability trong Info.plist
- ✅ NFCReaderUsageDescription
- ✅ NDEF format support
- ✅ Requires iPhone 7+

### 📝 Documentation

- ✅ README.md với hướng dẫn đầy đủ
- ✅ HUONG_DAN.md - Hướng dẫn sử dụng nhanh
- ✅ TAI_LIEU_KY_THUAT.md - Tài liệu kỹ thuật chi tiết
- ✅ CHANGELOG.md - Lịch sử thay đổi
- ✅ Code comments bằng tiếng Việt

### 🎯 Models

#### Employee Model

- employee_id (String, PK)
- name (String)
- department (String, nullable)
- position (String, nullable)

#### Attendance Model

- id (Integer, Auto-increment)
- employee_id (String, FK)
- employee_name (String)
- check_in_time (DateTime)
- status (String: "Đi làm" / "Đi muộn")

### 🔍 Data Flow

```
Ghi thẻ NFC:
User Input → Validation → Save to DB → Write to NFC → Success

Điểm danh:
Scan NFC → Read Data → Validate Employee → Check Duplicate →
Calculate Status → Save Attendance → Show Result

Xem danh sách:
Load Employees → Check Today's Attendance → Display with Status
```

### 📊 Statistics Features

- Tổng số nhân viên
- Số người đã điểm danh hôm nay
- Số người chưa điểm danh
- Lịch sử 7 ngày gần nhất

### 🎨 UI Components

- Custom cards với elevation
- Circular avatars với status badges
- Status chips (Đi làm/Đi muộn/Chưa điểm danh)
- Large action buttons
- Info cards với instructions
- Dialogs với icons

### 🔒 Validation Rules

- Mã nhân viên: bắt buộc
- Tên nhân viên: bắt buộc
- Điểm danh: chỉ 1 lần/ngày
- Thời gian: tự động lấy từ hệ thống

### ⚙️ Configuration

- Giờ đi làm chuẩn: 8:30 AM
- Định dạng ngày: dd/MM/yyyy
- Định dạng giờ: HH:mm
- Database name: smartcheck.db

---

## [Planned] - Future Versions

### v1.1.0 (Planned)

- [ ] Xuất báo cáo Excel
- [ ] Xuất báo cáo PDF
- [ ] Filter theo ngày/tháng
- [ ] Search functionality

### v1.2.0 (Planned)

- [ ] Cloud sync với Firebase
- [ ] Real-time updates
- [ ] Push notifications
- [ ] Email reports

### v1.3.0 (Planned)

- [ ] Face recognition
- [ ] GPS location check
- [ ] QR code backup
- [ ] Multiple shifts support

### v2.0.0 (Planned)

- [ ] Web dashboard
- [ ] Multi-company support
- [ ] Role-based access
- [ ] Advanced analytics

---

## Version History

- **v1.0.0** (2024-12-01) - Initial release
  - Core attendance system
  - NFC read/write
  - SQLite database
  - 3 main screens
  - Vietnamese localization

---

## Notes

### Giới hạn hiện tại:

- Chỉ hỗ trợ 1 điểm danh/ngày
- Không có tính năng checkout
- Không có quản lý ca làm việc
- Dữ liệu lưu local only
- Không có authentication

### Yêu cầu cải tiến:

- Thêm unit tests
- Thêm widget tests
- Thêm integration tests
- Implement CI/CD
- Add error tracking (Sentry/Firebase Crashlytics)

---

**Format dựa trên [Keep a Changelog](https://keepachangelog.com/)**
