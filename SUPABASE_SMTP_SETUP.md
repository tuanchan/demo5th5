# Cấu hình email xác thực cho Supabase

Ứng dụng gửi email đăng ký và khôi phục mật khẩu qua Supabase Auth. Không đặt
mật khẩu SMTP trong mã Flutter, asset, `.env` đóng gói cùng app hoặc Git.

## 1. Tạo lại mật khẩu ứng dụng Gmail

Mật khẩu đã từng được gửi trong hội thoại cần được thu hồi. Tạo một App Password
mới trong Google Account và chỉ nhập trực tiếp vào Supabase Dashboard.

## 2. Bật xác thực email

Trong Supabase Dashboard của project:

1. Mở **Authentication → Providers → Email**.
2. Bật Email provider.
3. Bật **Confirm email**.
4. Không bật tự động xác nhận email.

## 3. Cấu hình Custom SMTP

Mở **Authentication → Emails → SMTP Settings**, bật Custom SMTP và nhập:

- Sender email: địa chỉ Gmail gửi thư
- Sender name: `Flash Cards`
- Host: `smtp.gmail.com`
- Port: `587`
- Username: địa chỉ Gmail gửi thư
- Password: App Password Gmail mới

Không ghi App Password vào file này.

## 4. URL xác nhận

Trong **Authentication → URL Configuration**, thêm Redirect URL:

```text
com.example.flutterflashcard://login-callback/
http://localhost:3000/
```

Web production cần thêm origin thật của website. Desktop cần một HTTPS Site URL
hợp lệ để trang xác nhận có nơi chuyển về sau khi Supabase xác thực xong.

## 5. Email template xác thực bằng OTP

Trong **Authentication → Emails → Templates → Confirm signup**, dùng biến
`{{ .Token }}` để email chứa mã OTP 8 số mà ứng dụng có thể xác thực:

```html
<h2>Xác thực tài khoản Flash Cards</h2>
<p>Mã xác thực của bạn là:</p>
<p style="font-size:32px;font-weight:700;letter-spacing:8px">
  {{ .Token }}
</p>
<p>Mã có thời hạn sử dụng. Không chia sẻ mã này với người khác.</p>
```

Supabase chỉ hỗ trợ OTP email từ 6 đến 10 số, không hỗ trợ mã 4 số. Project này
đang cấu hình và ứng dụng đang dùng OTP 8 số.

Template Reset password vẫn dùng `{{ .ConfirmationURL }}` vì luồng đặt lại mật
khẩu mở liên kết khôi phục. Có thể đổi nội dung và màu sắc nhưng không thay các
biến liên kết/mã tương ứng.
