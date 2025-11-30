# 📱 Hướng dẫn cấu hình NFC cho iOS

## Yêu cầu

- Xcode 12.0 trở lên
- iPhone 7 trở lên (có chip NFC)
- iOS 11.0 trở lên
- Apple Developer Account (để test trên thiết bị thật)

## Bước 1: Mở project trong Xcode

```bash
cd ios
open Runner.xcworkspace
```

⚠️ **Lưu ý:** Mở file `.xcworkspace`, KHÔNG phải `.xcodeproj`

## Bước 2: Thêm NFC Capability

1. Trong Xcode, chọn project **Runner** ở sidebar trái
2. Chọn target **Runner**
3. Chọn tab **"Signing & Capabilities"**
4. Click nút **"+ Capability"**
5. Tìm và thêm **"Near Field Communication Tag Reading"**

## Bước 3: Cấu hình Info.plist

File `ios/Runner/Info.plist` đã được cấu hình với:

```xml
<key>NFCReaderUsageDescription</key>
<string>Ứng dụng cần quyền truy cập NFC để đọc và ghi thẻ điểm danh nhân viên</string>

<key>com.apple.developer.nfc.readersession.formats</key>
<array>
    <string>NDEF</string>
</array>
```

✅ Bạn không cần chỉnh sửa gì thêm.

## Bước 4: Cấu hình Entitlements

Xcode sẽ tự động tạo file `Runner.entitlements` khi bạn thêm capability.

Kiểm tra file này có nội dung:

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

## Bước 5: Cấu hình Bundle Identifier

1. Trong Xcode, chọn target **Runner**
2. Tab **"General"**
3. Trong **"Identity"**, đặt một **Bundle Identifier** duy nhất
   - Ví dụ: `com.yourcompany.smartchecknfc`

## Bước 6: Signing

1. Trong tab **"Signing & Capabilities"**
2. Chọn **Team** của bạn
3. Đảm bảo **"Automatically manage signing"** được bật

⚠️ **Lưu ý:** Bạn cần Apple Developer Account để test trên thiết bị thật.

## Bước 7: Build và Run

### Option 1: Từ Xcode

1. Kết nối iPhone
2. Chọn device ở thanh toolbar
3. Nhấn **Cmd + R** để build và run

### Option 2: Từ Terminal

```bash
flutter run -d <device-id>
```

Xem danh sách devices:

```bash
flutter devices
```

## Test NFC

### 1. Kiểm tra NFC có hoạt động

```dart
final isAvailable = await NfcManager.instance.isAvailable();
print('NFC Available: $isAvailable');
```

### 2. Test đọc thẻ

- Mở app
- Nhấn nút "QUÉT THẺ NFC"
- Đưa thẻ NFC (NDEF) đến mặt sau iPhone
- Vị trí chip NFC thường ở giữa mặt sau, gần camera

### 3. Test ghi thẻ

- Vào màn hình "Ghi thẻ NFC"
- Nhập thông tin
- Nhấn "GHI VÀO THẺ NFC"
- Đưa thẻ NFC đến iPhone

## Troubleshooting

### Lỗi: "NFC not available"

**Nguyên nhân:**

- Thiết bị không hỗ trợ NFC (iPhone < 7)
- iOS version < 11.0
- NFC bị tắt trong Settings

**Giải pháp:**

- Kiểm tra model iPhone
- Update iOS lên version mới nhất
- Settings → NFC → Bật ON

### Lỗi: "App ID does not include NFC capability"

**Nguyên nhân:**

- Chưa thêm NFC capability trong Xcode
- Bundle ID chưa được đăng ký với NFC

**Giải pháp:**

1. Thêm NFC capability như hướng dẫn ở Bước 2
2. Clean build: Product → Clean Build Folder (Cmd + Shift + K)
3. Build lại

### Lỗi: "NFC session timeout"

**Nguyên nhân:**

- Thẻ NFC không được đưa đến đúng vị trí
- Thẻ không hỗ trợ NDEF

**Giải pháp:**

- Thử vị trí khác trên mặt sau iPhone
- Giữ thẻ không di chuyển
- Kiểm tra thẻ có hỗ trợ NDEF không

### Lỗi: "Tag type not supported"

**Nguyên nhân:**

- Thẻ NFC không phải NDEF format

**Giải pháp:**

- Sử dụng thẻ NDEF (NFC Forum Type 2/4/5)
- Format thẻ thành NDEF bằng app khác

### Lỗi: Build failed với "Provisioning profile error"

**Nguyên nhân:**

- Chưa có provisioning profile hợp lệ
- Team không được chọn

**Giải pháp:**

1. Đăng nhập Apple ID trong Xcode
2. Chọn Team trong Signing settings
3. Xcode sẽ tự động tạo provisioning profile

## Thẻ NFC tương thích

### ✅ Hỗ trợ (NDEF format):

- **NFC Forum Type 2**: NTAG213, NTAG215, NTAG216
- **NFC Forum Type 4**: MIFARE DESFire
- **NFC Forum Type 5**: ICODE SLIX

### ❌ Không hỗ trợ trực tiếp:

- MIFARE Classic (cần format NDEF)
- Thẻ proprietary format

## Khuyến nghị

### Thẻ NFC tốt nhất:

1. **NTAG213** (144 bytes) - Rẻ, phổ biến
2. **NTAG215** (504 bytes) - Dung lượng vừa
3. **NTAG216** (888 bytes) - Dung lượng lớn

### Mua thẻ ở đâu:

- Amazon
- AliExpress
- Shopee/Lazada (Việt Nam)
- Cửa hàng điện tử

Giá: ~500-2.000đ/thẻ

## Kiểm tra thẻ NFC

### Sử dụng app có sẵn:

1. **NFC Tools** (iOS App Store)
   - Đọc/ghi thẻ NDEF
   - Kiểm tra thông tin thẻ
2. **NFC TagInfo**
   - Xem chi tiết kỹ thuật
   - Check compatibility

## Testing Tips

### 1. Vị trí chip NFC trên iPhone:

| Model       | Vị trí chip              |
| ----------- | ------------------------ |
| iPhone 7-8  | Giữa mặt sau, phía trên  |
| iPhone X-11 | Giữa mặt sau, gần camera |
| iPhone 12+  | Giữa mặt sau, chính giữa |

### 2. Cách cầm thẻ:

- Đưa thẻ sát mặt sau iPhone
- Giữ thẳng, không nghiêng
- Không di chuyển khi đang đọc/ghi
- Đợi 1-2 giây

### 3. Môi trường test:

- Tránh xa kim loại
- Tránh nhiều thẻ NFC gần nhau
- Test trong nhà, không nhiễu sóng

## Debug Mode

### Bật debug logs:

```dart
// Trong nfc_service.dart, thêm logs:
print('NFC Session started');
print('Tag discovered: $tag');
print('NDEF message: $message');
```

### Xem logs:

```bash
flutter logs
```

Hoặc trong Xcode: View → Debug Area → Show Console

## Production Build

Khi build cho production:

```bash
# Build iOS app
flutter build ios --release

# Tạo IPA file
flutter build ipa
```

## App Store Submission

Trước khi submit lên App Store, đảm bảo:

1. ✅ Info.plist có NFCReaderUsageDescription rõ ràng
2. ✅ Entitlements được cấu hình đúng
3. ✅ Screenshot có chức năng NFC
4. ✅ App description giải thích cách dùng NFC
5. ✅ Test kỹ trên nhiều thiết bị

## Tài liệu tham khảo

- [Apple NFC Documentation](https://developer.apple.com/documentation/corenfc)
- [nfc_manager plugin](https://pub.dev/packages/nfc_manager)
- [Flutter iOS setup](https://docs.flutter.dev/deployment/ios)

---

**Gặp vấn đề? Tạo issue trên GitHub! 🚀**
