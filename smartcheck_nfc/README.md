# SmartCheck NFC - Hệ thống điểm danh nhân viên bằng thẻ NFC

Ứng dụng điểm danh nhân viên nhanh chóng sử dụng công nghệ NFC, không cần sổ giấy hay máy quét thẻ đắt tiền.

## 🎯 Tính năng chính

### 1. Ghi thẻ NFC cho nhân viên

- Nhập thông tin nhân viên (Mã NV, Tên, Phòng ban, Chức vụ)
- Ghi dữ liệu vào thẻ NFC
- Tự động lưu vào database

### 2. Điểm danh bằng thẻ NFC

- Quét thẻ NFC để điểm danh
- Tự động ghi lại thời gian
- Phân loại trạng thái (Đi làm, Đi muộn)
- Kiểm tra trùng lặp (không cho điểm danh 2 lần/ngày)

### 3. Quản lý nhân viên

- Xem danh sách tất cả nhân viên
- Hiển thị trạng thái điểm danh hôm nay
- Xem lịch sử điểm danh 7 ngày gần nhất
- Thống kê số người đã/chưa điểm danh

### 4. Màn hình chính

- Hiển thị danh sách điểm danh hôm nay
- Nút quét NFC lớn, dễ sử dụng
- Thống kê tổng số người đã điểm danh

## 📱 Yêu cầu hệ thống

- **Android**: Android 5.0 (API level 21) trở lên, có NFC
- **iOS**: iOS 11.0 trở lên, có NFC (iPhone 7 trở lên)
- **Flutter**: SDK 3.10.1 trở lên

## 🚀 Cài đặt và chạy

### 1. Cài đặt dependencies

```bash
flutter pub get
```

### 2. Chạy ứng dụng

#### Android

```bash
flutter run
```

#### iOS

- Mở `ios/Runner.xcworkspace` bằng Xcode
- Thêm "Near Field Communication Tag Reader Session Formats" capability
- Chọn target device và run

### 3. Cấu hình iOS (quan trọng)

Để sử dụng NFC trên iOS, cần:

1. Mở Xcode và chọn project `Runner`
2. Vào tab "Signing & Capabilities"
3. Click nút "+" và thêm "Near Field Communication Tag Reading"
4. Tạo file `ios/Runner/Runner.entitlements` nếu chưa có:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.nfc.readersession.formats</key>
    <array>
        <string>NDEF</string>
    </array>
</dict>
</plist>
```

## 📋 Cấu trúc dự án

```
lib/
├── main.dart                    # Entry point
├── models/
│   ├── employee.dart            # Model nhân viên
│   └── attendance.dart          # Model điểm danh
├── services/
│   ├── database_helper.dart     # SQLite database
│   └── nfc_service.dart         # NFC read/write
└── screens/
    ├── home_screen.dart         # Màn hình chính
    ├── write_nfc_screen.dart    # Màn hình ghi thẻ
    └── employee_list_screen.dart # Danh sách nhân viên
```

## 🎮 Hướng dẫn sử dụng

### Bước 1: Ghi thẻ NFC cho nhân viên

1. Mở ứng dụng
2. Nhấn icon NFC ở góc trên bên phải
3. Nhập thông tin nhân viên:
   - Mã nhân viên (bắt buộc): VD: EMP001
   - Tên nhân viên (bắt buộc): VD: Nguyễn Văn A
   - Phòng ban (tùy chọn): VD: Kỹ thuật
   - Chức vụ (tùy chọn): VD: Lập trình viên
4. Nhấn nút "GHI VÀO THẺ NFC"
5. Đưa thẻ NFC đến điện thoại
6. Giữ thẻ cho đến khi có thông báo thành công

### Bước 2: Điểm danh nhân viên

1. Ở màn hình chính, nhấn nút "QUÉT THẺ NFC"
2. Nhân viên đưa thẻ NFC đến điện thoại
3. Hệ thống tự động:
   - Đọc thông tin từ thẻ
   - Kiểm tra nhân viên có trong database
   - Kiểm tra đã điểm danh hôm nay chưa
   - Ghi lại thời gian điểm danh
   - Hiển thị thông báo thành công

### Bước 3: Xem danh sách và thống kê

1. Nhấn icon người (👥) để xem danh sách nhân viên
2. Xem trạng thái điểm danh của từng người
3. Nhấn vào nhân viên để xem chi tiết và lịch sử

## 📊 Quy định điểm danh

- **Đi làm**: Điểm danh trước 8:30 sáng
- **Đi muộn**: Điểm danh sau 8:30 sáng
- Mỗi nhân viên chỉ được điểm danh 1 lần/ngày

## 🔧 Công nghệ sử dụng

- **Flutter**: Framework UI
- **nfc_manager**: Đọc/ghi NFC
- **sqflite**: SQLite database local
- **intl**: Định dạng ngày tháng
- **path**: Quản lý đường dẫn file

## 📱 Screenshots

### Màn hình chính

- Hiển thị danh sách điểm danh hôm nay
- Nút quét NFC
- Thống kê số người đã điểm danh

### Màn hình ghi thẻ

- Form nhập thông tin nhân viên
- Nút ghi vào thẻ NFC
- Hướng dẫn sử dụng

### Màn hình danh sách nhân viên

- Danh sách tất cả nhân viên
- Trạng thái điểm danh
- Thống kê tổng quan

## 🐛 Xử lý lỗi thường gặp

### NFC không hoạt động

- Kiểm tra thiết bị có hỗ trợ NFC không
- Bật NFC trong cài đặt điện thoại
- Android: Kiểm tra quyền trong AndroidManifest.xml
- iOS: Kiểm tra Info.plist và entitlements

### Không đọc được thẻ

- Đưa thẻ gần hơn với điện thoại
- Giữ thẻ không di chuyển trong khi đọc/ghi
- Thử vị trí khác trên mặt sau điện thoại
- Kiểm tra thẻ có hỗ trợ NDEF không

### Database lỗi

- Xóa ứng dụng và cài lại
- Xóa cache: Settings -> Apps -> SmartCheck NFC -> Clear Data

## 📝 Dữ liệu mẫu

Ứng dụng đã có sẵn 3 nhân viên mẫu:

- EMP001 - Nguyễn Văn A (Kỹ thuật - Lập trình viên)
- EMP002 - Trần Thị B (Nhân sự - Trưởng phòng)
- EMP003 - Lê Văn C (Kỹ thuật - Tester)

## 🔐 Bảo mật

- Dữ liệu lưu local trên thiết bị
- Không gửi thông tin lên internet
- Mã hóa database (có thể thêm nếu cần)

## 🚧 Tính năng sẽ phát triển

- [ ] Xuất báo cáo Excel/PDF
- [ ] Đồng bộ dữ liệu lên cloud
- [ ] Chấm công về sớm
- [ ] Thông báo cho admin khi có người điểm danh
- [ ] Quản lý ca làm việc
- [ ] Tính công theo tháng

## 👨‍💻 Phát triển bởi

SmartCheck NFC Team

## 📄 License

MIT License
