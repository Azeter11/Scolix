# Mengarahkan cache package ke Disk D (Flutter/Gradle/Dart)

Tujuan: menghindari download cache ke **C:** karena penuh.

## 1) Set environment variables (sekali saja per user)
Jalankan di Command Prompt (CMD) **sebagai user biasa**:

```bat
setx GRADLE_USER_HOME "D:\\gradle"
setx PUB_CACHE "D:\\.pub-cache"

REM (opsional) jika Anda punya Android SDK di D:
setx ANDROID_HOME "D:\\tugas\\AndroidSDK"
setx ANDROID_SDK_ROOT "D:\\tugas\\AndroidSDK"
```

Catatan:
- `setx` butuh buka CMD baru agar efeknya kebaca.
- Folder akan dibuat otomatis ketika pertama kali dipakai.

## 2) Pastikan Android SDK sudah mengarah ke D
Cek file: `android/local.properties`

Harus mirip seperti ini:
```properties
sdk.dir=D:\\tugas\\AndroidSDK
```

## 3) Bersihkan output build agar tidak pakai cache lama
```bat
flutter clean
```

Jika masih bermasalah, hapus build/ di root:
```bat
rmdir /s /q build
```

## 4) Ambil package
```bat
flutter pub get
```

## 5) Build ulang
```bat
flutter run
REM atau
flutter build apk
```

## 6) Verifikasi lokasi cache
- Gradle: pastikan ada folder `D:\\gradle\\caches` / `D:\\gradle\\wrapper`
- Pub/Dart: pastikan ada `D:\\.pub-cache`

