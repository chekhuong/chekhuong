# TodoLock – Việc cần làm & lịch trên màn hình khóa iPad

App cá nhân lấy cảm hứng từ **LockDay: To-Do List & Planner**: đưa danh sách việc cần làm và lịch
lên **màn hình khóa** và **màn hình chính** của iPad. Viết bằng SwiftUI + WidgetKit, hỗ trợ iPadOS 17 trở lên.
Dữ liệu chỉ nằm trên máy, không cần tài khoản, không gửi đi đâu.

## Tính năng

| | |
|---|---|
| 🔒 **Widget màn hình khóa** | *Việc hôm nay* (chữ nhật, tròn có vòng tiến độ, một dòng) và *Lịch trình* (việc/sự kiện tiếp theo) |
| 🏠 **Widget màn hình chính** | Nhỏ / Vừa / Lớn / Cực lớn (iPad). **Bấm ✓ để đánh dấu xong ngay trên widget** |
| ✅ **Việc cần làm** | Ngày, giờ, ghi chú, độ ưu tiên, màu, quá hạn, dời sang mai, vuốt để xoá/hoàn thành |
| 🔁 **Lặp lại** | Hằng ngày, ngày thường (T2–T6), hằng tuần, hằng tháng, hằng năm, có ngày kết thúc |
| ⚡ **Thêm nhanh** | Gõ `9:30 Họp nhóm` hoặc `Gọi mẹ 20h`, app tự nhận giờ |
| 📅 **Lịch tháng** | Lưới tháng (tuần bắt đầu Thứ Hai) có chấm màu, vuốt để đổi tháng, xem việc theo ngày |
| 🗓 **Lịch hệ thống** | Hiện sự kiện trong app Lịch (iCloud/Google…) cạnh việc cần làm và trên widget |
| 🔔 **Nhắc nhở** | Thông báo đúng giờ, kể cả việc lặp lại; giờ nhắc mặc định cho việc không có giờ |
| 💾 **Sao lưu** | Xuất/nhập file JSON qua app Tệp |
| 🎨 **Giao diện** | Bố cục chia cột cho iPad, chọn màu nhấn, chế độ tối, phím tắt ⌘N |

## Cài lên iPad (cần một máy Mac)

1. Cài **Xcode** (App Store) và **XcodeGen**: `brew install xcodegen`
2. Mở `project.yml`, sửa 2 dòng:
   - `APP_BUNDLE_ID`: đổi thành tên riêng, ví dụ `com.tenban.todolock` (bắt buộc phải là duy nhất)
   - `DEVELOPMENT_TEAM`: Team ID (để trống cũng được, rồi chọn Team trong Xcode ở bước 4)
3. Chạy `xcodegen generate`, rồi mở `TodoLock.xcodeproj`
4. Trong Xcode, vào **Settings → Accounts** và đăng nhập Apple ID (tài khoản miễn phí cũng được).
   Ở mục *Signing & Capabilities* của **cả 2 target** `TodoLock` và `TodoLockWidget`, chọn Team của bạn.
5. Cắm iPad, chọn iPad làm đích chạy rồi bấm ▶︎ Run
6. Trên iPad, vào **Cài đặt → Cài đặt chung → VPN & Quản lý thiết bị**, chọn tin cậy nhà phát triển.
   Với iPadOS 16 trở lên, còn phải bật **Cài đặt → Quyền riêng tư & Bảo mật → Chế độ nhà phát triển**.

> **Lưu ý:** App ký bằng Apple ID miễn phí chỉ dùng được **7 ngày**, hết hạn thì cắm máy và bấm Run lại.
> Dữ liệu vẫn còn nguyên. Tài khoản Apple Developer trả phí thì dùng được 1 năm.

### Không có Mac?
Mỗi lần push, GitHub Actions sẽ build một file `TodoLock-unsigned.ipa`, tải ở tab **Actions → Artifacts**.
Sau đó dùng **Sideloadly** hoặc **AltStore** (trên Windows/Mac) để ký bằng Apple ID và cài lên iPad.
Một số công cụ sideload không giữ được *App Group*. Khi đó app vẫn chạy, nhưng widget không thấy dữ liệu
(trong Cài đặt của app sẽ có cảnh báo).

## Thêm widget vào màn hình khóa iPad
Khóa iPad → chạm và giữ màn hình khóa → **Tùy chỉnh** → **Màn hình khóa** → chạm vào vùng widget
→ chọn **TodoLock** → **Việc hôm nay** hoặc **Lịch trình**.

## Cấu trúc mã
```
project.yml            Cấu hình XcodeGen (app + widget extension, App Group)
Shared/                Dùng chung cho app & widget: model, lưu trữ JSON, lặp lại, EventKit, AppIntent
App/                   Ứng dụng SwiftUI (TaskStore, thông báo, router, các màn hình trong Views/)
Widget/                WidgetKit: Việc hôm nay, Lịch trình
```
Dữ liệu được lưu ở `tasks.json` trong App Group, nên app và widget cùng đọc một nguồn.
Widget đánh dấu xong thông qua `ToggleTaskIntent` (App Intents).
