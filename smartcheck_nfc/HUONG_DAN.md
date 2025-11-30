# 🚀 HƯỚNG DẪN SỬ DỤNG NHANH

## Cài đặt

```bash
# 1. Cài đặt dependencies
flutter pub get

# 2. Chạy ứng dụng
flutter run
```

## Sử dụng

### 📝 Bước 1: Ghi thẻ NFC cho nhân viên

1. Mở app → Nhấn icon **NFC** (góc trên phải)
2. Nhập thông tin:
   - **Mã NV**: EMP032
   - **Tên**: Nguyễn Văn A
   - **Phòng ban**: Kỹ thuật (tùy chọn)
   - **Chức vụ**: Lập trình viên (tùy chọn)
3. Nhấn **"GHI VÀO THẺ NFC"**
4. Đưa thẻ NFC đến điện thoại
5. Chờ thông báo thành công ✅

### ✅ Bước 2: Điểm danh

1. Màn hình chính → Nhấn **"QUÉT THẺ NFC"**
2. Nhân viên đưa thẻ đến điện thoại
3. Xem thông báo: "Điểm danh thành công - Xin chào: Nguyễn Văn A"

### 📊 Bước 3: Xem danh sách

1. Nhấn icon **👥** (góc trên phải)
2. Xem:
   - Tổng số nhân viên
   - Ai đã điểm danh
   - Ai chưa điểm danh
3. Nhấn vào nhân viên → Xem lịch sử 7 ngày

## Quy định

- ✅ **Đi làm**: Trước 8:30
- ⚠️ **Đi muộn**: Sau 8:30
- ❌ Mỗi người chỉ điểm danh **1 lần/ngày**

## Lưu ý iOS

Cần thêm NFC capability trong Xcode:

1. Mở `ios/Runner.xcworkspace`
2. Vào "Signing & Capabilities"
3. Thêm "Near Field Communication Tag Reading"

## Dữ liệu mẫu

App có sẵn 3 nhân viên:

- **EMP001** - Nguyễn Văn A
- **EMP002** - Trần Thị B
- **EMP003** - Lê Văn C

## Xử lý lỗi

### NFC không hoạt động?

- Bật NFC trong cài đặt điện thoại
- Đưa thẻ gần hơn
- Giữ thẻ không di chuyển

### Đã điểm danh rồi?

- Mỗi người chỉ điểm danh 1 lần/ngày
- Sang ngày mới mới điểm danh được

### Không tìm thấy nhân viên?

- Đảm bảo đã ghi thẻ NFC cho nhân viên đó
- Kiểm tra mã nhân viên có đúng không

## 📞 Hỗ trợ

Gặp vấn đề? Mở issue trên GitHub hoặc liên hệ team phát triển.

---

**Chúc bạn sử dụng thành công! 🎉**
