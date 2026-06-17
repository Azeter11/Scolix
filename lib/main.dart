import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await MobileAds.instance.initialize();
  runApp(const ScolixApp());
}

class ScolixApp extends StatelessWidget {
  const ScolixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Scolix Mobile',
      theme: ThemeData(
        useMaterial3: false,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const SplashScreen(),
    );
  }
}

class AppColors {
  static const blue = Color(0xff2545ff);
  static const softPanel = Color(0xffdce6ff);
  static const lightBlue = Color(0xffe8efff);
}

const String aiBackendUrl = 'https://scolix-api-production.up.railway.app/chat';

const String otpBackendUrl = 'https://scolix-api-production.up.railway.app';

Future<bool> ensureCameraPermission({BuildContext? context}) async {
  try {
    final status = await Permission.camera.status;

    if (status.isGranted) return true;

    final result = await Permission.camera.request();

    if (result.isGranted) return true;

    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Izin kamera diperlukan untuk analisis postur.'),
        ),
      );
    }

    return false;
  } catch (_) {
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal meminta izin kamera.'),
        ),
      );
    }
    return false;
  }
}

BoxDecoration bgGradient() => const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xff3048ff), Color(0xff8aa5f2), Color(0xffd6f7f4)],
      ),
    );

bool isValidGmail(String email) =>
    RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$').hasMatch(email.trim());

bool isValidPhone(String phone) =>
    RegExp(r'^[0-9]{11,}$').hasMatch(phone.trim());

bool hasUppercase(String password) => RegExp(r'[A-Z]').hasMatch(password);

bool hasNumberOrSymbol(String password) =>
    RegExp(r'[0-9!@#\$%^&*(),.?":{}|<>]').hasMatch(password);

bool isValidPassword(String password) =>
    password.length >= 8 &&
    hasUppercase(password) &&
    hasNumberOrSymbol(password);

Future<void> openUrl(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link tidak bisa dibuka')));
  }
}

class AiChatService {
  static Future<String> ask(String message) async {
    try {
      // ScanRepository is not defined in this project.
      // Keep payload simple and let backend answer without lastScan.
      final res = await http
          .post(
            Uri.parse(aiBackendUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'message': message}),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        return data['reply']?.toString() ?? 'AI belum memberikan jawaban.';
      }

      return AiFallback.answer(message);
    } catch (_) {
      return AiFallback.answer(message);
    }
  }
}

class AiFallback {
  static String answer(String question) {
    final q = question.toLowerCase();
    if (q.contains('hasil') || q.contains('scan')) {
      if (ScanRepository.histories.isNotEmpty) {
        final r = ScanRepository.histories.first;
        return 'Hasil scan terakhir menunjukkan status ${r.status}, kemiringan bahu ${r.result.tilt}°, panggul ${r.result.pelvis}. ${r.recommendation}\n\nUntuk edukasi dan skrining awal postur. Bukan alat pemeriksaan klinis..';
      }
      return 'Belum ada hasil scan. Buka menu Pengguna, isi data, lalu tekan Mulai Analisis.';
    }

    if (q.contains('postur')) {
      return 'Postur tubuh yang baik membantu keseimbangan dan kenyamanan aktivitas sehari-hari.';
    }

    if (q.contains('scanner')) {
      return 'Gunakan kamera dengan posisi tubuh tegak dan pencahayaan cukup.';
    }

    if (q.contains('hasil')) {
      return 'Hasil analisis membantu memahami pola postur secara visual.';
    }

    return 'Saya membantu edukasi postur tubuh, penggunaan scanner, dan informasi fitur aplikasi.';
  }
}

class MainButton extends StatelessWidget {
  final String text;

  final VoidCallback? onTap;

  final bool loading;

  const MainButton({
    super.key,
    required this.text,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: loading
            ? null
            : () {
                FocusScope.of(context).unfocus();

                onTap?.call();
              },
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff233CFF), Color(0xffC8F1F4)],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    text,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class CustomInput extends StatefulWidget {
  final String label;
  final String hint;
  final bool password;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final void Function(String)? onChanged;

  const CustomInput({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.password = false,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.onChanged,
  });

  @override
  State<CustomInput> createState() => _CustomInputState();
}

class _CustomInputState extends State<CustomInput> {
  bool obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          validator: widget.validator,
          onChanged: widget.onChanged,
          keyboardType: widget.keyboardType,
          obscureText: widget.password ? obscure : false,
          decoration: InputDecoration(
            hintText: widget.hint,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            suffixIcon: widget.password
                ? IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        obscure = !obscure;
                      });
                    },
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

Widget footer() => const Column(
      children: [
        Divider(color: Colors.black54),
        SizedBox(height: 12),
        Text(
          '⌁  Scolix - AI',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ],
    );

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    checkSession();
  }

  Future<void> checkSession() async {
    await Future.delayed(const Duration(seconds: 2));

    try {
      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final role = doc.data()?['role'] ?? 'user';

      if (!mounted) return;

      if (role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (e) {
      debugPrint("FIRESTORE ERROR: $e");

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: bgGradient(),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/Icon.png', width: 140),
              const SizedBox(height: 25),
              const Text(
                'SCOLIX Mobile',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Analisis keseimbangan postur tubuh berbasis kamera',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FirebaseAuthService {
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: '1077454726059-vk1eagkrs4830fq1n0vhng1lhjt82n92.apps.googleusercontent.com',
      );
      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      await saveUserToFirestore(userCredential.user);

      return userCredential;
    } catch (e) {
      debugPrint("Google Login Error:$e");

      rethrow;
    }
  }

  static Future<void> saveUserToFirestore(
    User? user, {
    String role = 'user',
  }) async {
    if (user == null) return;

    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);

    final snap = await ref.get();

    await ref.set({
      'uid': user.uid,
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'photoUrl': user.photoURL ?? '',
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
      if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loginLoading = false;
  bool googleLoading = false;
  bool rememberMe = false;
  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> handleGoogleSignIn() async {
    setState(() {
      googleLoading = true;
    });

    try {
      final userCredential = await FirebaseAuthService.signInWithGoogle();

      if (userCredential == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      final role = doc.data()?['role'] ?? 'user';

      if (!mounted) return;

      if (role == "admin") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (e) {
      String errorMsg = 'Google login gagal';
      
      if (e.toString().contains('network_error')) {
        errorMsg = 'Tidak ada koneksi internet';
      } else if (e.toString().contains('sign_in_canceled')) {
        errorMsg = 'Login dibatalkan oleh user';
      } else if (e.toString().contains('sign_in_failed')) {
        errorMsg = 'Gagal login Google. Coba lagi.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $errorMsg'),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (mounted) {
      setState(() {
        googleLoading = false;
      });
    }
  }

  Future<void> loginEmailPassword() async {
    if (loginLoading) return;

    if (!formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      loginLoading = true;
    });

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .get();

      final role = doc.data()?['role'] ?? 'user';

      if (!mounted) return;

      if (role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email atau password salah')),
      );
    } finally {
      if (mounted) {
        setState(() {
          loginLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: bgGradient(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 45),
                const Text(
                  'Guided Capture + QC',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'Selamat datang!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Silahkan masuk untuk melanjutkan ke aplikasi',
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 45),
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xfff8f8ff),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 5),
                    ],
                  ),
                  child: Form(
                    key: formKey,
                    autovalidateMode: AutovalidateMode.disabled,
                    child: Column(
                      children: [
                        CustomInput(
                          label: 'Email',
                          hint: 'Masukan Email',
                          controller: emailController,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Email wajib diisi';
                            }
                            if (!isValidGmail(v)) {
                              return 'Email harus menggunakan format @gmail.com';
                            }
                            return null;
                          },
                        ),
                        CustomInput(
                          label: 'Password',
                          hint: 'Masukan Password',
                          password: true,
                          controller: passwordController,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Password wajib diisi';
                            }
                            if (!isValidPassword(v)) {
                              return 'Password minimal 8 karakter, 1 huruf besar, dan 1 angka/simbol';
                            }
                            return null;
                          },
                        ),
                        Row(
                          children: [
                            Checkbox(
                              value: rememberMe,
                              onChanged: (v) {
                                setState(() {
                                  rememberMe = v ?? false;
                                });
                              },
                            ),
                            const Text('Ingat saya'),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordPage(),
                                ),
                              ),
                              child: const Text(
                                'Lupa password?',
                                style: TextStyle(color: AppColors.blue),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        MainButton(
                          text: 'Masuk',
                          onTap: loginEmailPassword,
                          loading: loginLoading,
                        ),
                        const SizedBox(height: 18),
                        const Text('atau masuk dengan'),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: googleLoading ? null : handleGoogleSignIn,
                          child: googleLoading
                              ? const CircularProgressIndicator()
                              : Image.asset(
                                  'assets/images/Google.png',
                                  width: 44,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 70),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Belum punya akun? '),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterPage()),
                      ),
                      child: const Text(
                        'Daftar',
                        style: TextStyle(
                          color: AppColors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool registerLoading = false;
  bool googleLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> registerEmailPassword() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => registerLoading = true);

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      try {
        await cred.user?.updateDisplayName(nameController.text.trim());

        await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .set({
          'uid': cred.user!.uid,
          'name': nameController.text.trim(),
          'email': emailController.text.trim(),
          'phone': phoneController.text.trim(),
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 10));

        await cred.user?.sendEmailVerification();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Pendaftaran berhasil! Link verifikasi telah dikirim ke email Anda.'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EmailVerificationPage(
              email: emailController.text.trim(),
            ),
          ),
        );
      } catch (e) {
        // Rollback: Hapus user dari Auth jika Firestore gagal
        await cred.user?.delete();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Gagal menyimpan data ke database. Pastikan Firestore sudah aktif: $e')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pendaftaran gagal: $e')),
      );
    }

    if (mounted) {
      setState(() => registerLoading = false);
    }
  }

  Future<void> registerWithGoogle() async {
    setState(() => googleLoading = true);
    try {
      final user = await FirebaseAuthService.signInWithGoogle();
      if (!mounted) return;
      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Google daftar gagal')));
    } finally {
      if (mounted) setState(() => googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: bgGradient(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Text(
                  'Buat akun baru',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Mulai analisa postur dengan AI',
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 35),
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xfff8f8ff),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 5),
                    ],
                  ),
                  child: Form(
                    key: formKey,
                    autovalidateMode: AutovalidateMode.disabled,
                    child: Column(
                      children: [
                        CustomInput(
                          label: 'Nama lengkap',
                          hint: 'Masukan Nama Lengkap',
                          controller: nameController,
                          validator: (v) => v == null || v.isEmpty
                              ? 'Nama lengkap wajib diisi'
                              : null,
                        ),
                        CustomInput(
                          label: 'Email',
                          hint: 'Masukan Email',
                          controller: emailController,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Email wajib diisi';
                            }
                            if (!isValidGmail(v)) {
                              return 'Email harus menggunakan format @gmail.com';
                            }
                            return null;
                          },
                        ),
                        CustomInput(
                          label: 'No. WhatsApp',
                          hint: 'Masukan No. WhatsApp',
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Nomor HP wajib diisi';
                            }
                            if (!isValidPhone(v)) {
                              return 'Nomor HP minimal 11 angka';
                            }
                            return null;
                          },
                        ),
                        CustomInput(
                          label: 'Password',
                          hint: 'Masukan Password',
                          password: true,
                          controller: passwordController,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Password wajib diisi';
                            }
                            if (!isValidPassword(v)) {
                              return 'Password minimal 8 karakter, 1 huruf besar, dan 1 angka/simbol';
                            }
                            return null;
                          },
                        ),
                        CustomInput(
                          label: 'Konfirmasi Password',
                          hint: 'Konfirmasi Password',
                          password: true,
                          controller: confirmPasswordController,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Konfirmasi password wajib diisi';
                            }
                            if (v != passwordController.text) {
                              return 'Konfirmasi password tidak sesuai';
                            }
                            return null;
                          },
                        ),
                        MainButton(
                          text: 'Daftar Sekarang',
                          onTap: registerEmailPassword,
                          loading: registerLoading,
                        ),
                        const SizedBox(height: 12),
                        const Text('atau daftar dengan'),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: googleLoading ? null : registerWithGoogle,
                          child: googleLoading
                              ? const CircularProgressIndicator()
                              : Image.asset(
                                  'assets/images/Google.png',
                                  width: 44,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 60),
                footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final emailController = TextEditingController();

  bool loading = false;
  bool emailSent = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> sendResetEmail() async {
    if (emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email tidak boleh kosong')),
      );
      return;
    }

    if (!isValidGmail(emailController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Format email tidak valid')),
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        emailSent = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Link reset password berhasil dikirim! Cek email Anda.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      String errorMsg = 'Gagal mengirim email reset password';
      
      if (e.toString().contains('user-not-found')) {
        errorMsg = 'Email tidak terdaftar di sistem';
      } else if (e.toString().contains('invalid-email')) {
        errorMsg = 'Format email tidak valid';
      } else if (e.toString().contains('too-many-requests')) {
        errorMsg = 'Terlalu banyak percobaan. Coba lagi nanti.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $errorMsg'),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xff2747FF),
              Color(0xffD8F0F4),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 25),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: Colors.white,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Guided Capture + QC",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                const Text(
                  "Lupa password?",
                  style: TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Masukkan email untuk menerima tautan reset",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 35),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 8,
                        offset: Offset(0, 4),
                        color: Colors.black12,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Email",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: "Masukkan Email",
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      MainButton(
                        text: loading ? "Mengirim..." : "Kirim tautan reset",
                        onTap: loading ? null : sendResetEmail,
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                if (emailSent)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 8,
                          offset: Offset(0, 4),
                          color: Colors.black12,
                        ),
                      ],
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.mail_outline,
                          size: 40,
                          color: Color(0xff647EFF),
                        ),
                        SizedBox(height: 10),
                        Text(
                          "Link reset akan dikirim ke email Anda",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "Periksa folder spam jika tidak ditemukan",
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 50),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text(
                    "Kembali ke login",
                  ),
                ),
                const SizedBox(height: 35),
                const Divider(),
                const SizedBox(height: 10),
                const Text(
                  "⌁ Scolix - AI",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EmailVerificationPage extends StatefulWidget {
  final String email;

  const EmailVerificationPage({super.key, required this.email});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool loading = false;
  String error = '';
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      checkVerification(auto: true);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> checkVerification({bool auto = false}) async {
    if (!auto) setState(() => loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      if (user?.emailVerified == true) {
        timer?.cancel();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SuccessPage()),
        );
      } else if (!auto) {
        setState(() => error = 'Email belum diverifikasi.');
      }
    } catch (e) {
      if (!auto) setState(() => error = 'Gagal mengecek status.');
    }
    if (!auto && mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: bgGradient(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 50),
                const Text("Verifikasi Email",
                    style: TextStyle(
                        fontSize: 28,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text("Tautan verifikasi telah dikirim ke\n${widget.email}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 35),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: [
                      const Icon(Icons.mark_email_unread_outlined,
                          size: 60, color: Color(0xff2747FF)),
                      const SizedBox(height: 20),
                      const Text(
                          "Silakan buka email Anda dan klik tautan verifikasi. Setelah itu, klik tombol di bawah.",
                          textAlign: TextAlign.center),
                      const SizedBox(height: 25),
                      if (error.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 15),
                            child: Text(error,
                                style: const TextStyle(color: Colors.red))),
                      MainButton(
                        text: loading ? "Mengecek..." : "Saya Sudah Verifikasi",
                        onTap: loading ? null : () => checkVerification(),
                      ),
                      const SizedBox(height: 15),
                      TextButton(
                        onPressed: () async {
                          await FirebaseAuth.instance.currentUser
                              ?.sendEmailVerification();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Email dikirim ulang.')));
                          }
                        },
                        child: const Text('Kirim Ulang Email'),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                TextButton.icon(
                  onPressed: () {
                    timer?.cancel();
                    Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => const LoginPage()));
                  },
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  label: const Text("Kembali ke Login",
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final formKey = GlobalKey<FormState>();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool get min8 => passwordController.text.length >= 8;
  bool get upper => hasUppercase(passwordController.text);
  bool get numberOrSymbol => hasNumberOrSymbol(passwordController.text);

  @override
  void initState() {
    super.initState();
    passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Widget req(String text, bool ok) => Row(
        children: [
          Icon(
            ok ? Icons.check : Icons.close,
            color: ok ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: bgGradient(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 25),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: Colors.white,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Guided Capture + QC",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  "Buat Password Baru",
                  style: TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Password harus memenuhi syarat keamanan",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 35),
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 8,
                        offset: Offset(0, 4),
                        color: Colors.black12,
                      ),
                    ],
                  ),
                  child: Form(
                    key: formKey,
                    child: Column(
                      children: [
                        CustomInput(
                          label: 'Password Baru',
                          hint: 'Masukkan Password Baru',
                          password: true,
                          controller: passwordController,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Password wajib diisi';
                            }

                            if (!isValidPassword(v)) {
                              return 'Password belum memenuhi ketentuan';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        CustomInput(
                          label: 'Konfirmasi Password',
                          hint: 'Konfirmasi Password',
                          password: true,
                          controller: confirmPasswordController,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Konfirmasi password wajib diisi';
                            }

                            if (v != passwordController.text) {
                              return 'Konfirmasi password tidak sesuai';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xffCDD8FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              req('Minimal 8 karakter', min8),
                              const SizedBox(height: 8),
                              req('1 huruf besar', upper),
                              const SizedBox(height: 8),
                              req('1 angka atau simbol', numberOrSymbol),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),
                        MainButton(
                          text: 'Simpan Password',
                          onTap: () async {
                            if (!formKey.currentState!.validate()) {
                              return;
                            }

                            try {
                              await FirebaseAuth.instance.currentUser
                                  ?.updatePassword(
                                passwordController.text,
                              );

                              await FirebaseAuth.instance.signOut();

                              if (!context.mounted) return;

                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SuccessPage(),
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Gagal mengubah password',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text(
                    "Kembali",
                  ),
                ),
                const SizedBox(height: 35),
                const Divider(),
                const SizedBox(height: 10),
                const Text(
                  "⌁ Scolix - AI",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SuccessPage extends StatelessWidget {
  const SuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: bgGradient(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 100),
                  const Icon(
                    Icons.check_circle_outline,
                    size: 120,
                    color: Color(0xff9bd1f5),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Berhasil!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Password telah direset',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 35),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xfff8f8ff),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Silahkan gunakan password baru untuk masuk ke akun Anda',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 25),
                        MainButton(
                          text: 'Masuk',
                          onTap: () => Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                            (r) => false,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 50),
                  footer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  const AppBottomNav({super.key, required this.currentIndex});

  void go(BuildContext context, int i) {
    if (i == currentIndex) return;

    if (i == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    }

    if (i == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const UserDataPage()),
      );
    }

    if (i == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HistoryPage()),
      );
    }
  }

  Widget navItem(BuildContext context, int index, String asset, String label) {
    final active = currentIndex == index;

    return GestureDetector(
      onTap: () => go(context, index),
      child: SizedBox(
        width: 92,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 50,
              decoration: BoxDecoration(
                color: active ? AppColors.lightBlue : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xffd6e3ff), width: 1.4),
              ),
              child: Center(
                child: Image.asset(
                  asset,
                  width: 27,
                  height: 27,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: TextStyle(
                fontSize: 12,
                height: 1,
                color: Colors.black,
                fontWeight: active ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 82,
        padding: const EdgeInsets.only(top: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.black, width: 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            navItem(context, 0, 'assets/images/Icon Beranda.png', 'Beranda'),
            navItem(context, 1, 'assets/images/Icon Paseien.png', 'Pengguna'),
            navItem(
              context,
              2,
              'assets/images/Icon Riwayat Homepgaes.png',
              'Riwayat',
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-3940256099942544/2934735716';

  // Interstitial Ad variables
  InterstitialAd? _interstitialAd;
  static bool _interstitialShownThisSession = false;

  @override
  void initState() {
    super.initState();
    _checkAndLoadInterstitialAd();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isAdLoaded) {
      _loadAd();
    }
  }

  void _checkAndLoadInterstitialAd() {
    debugPrint('Interstitial Ad: _interstitialShownThisSession = $_interstitialShownThisSession');

    if (!_interstitialShownThisSession) {
      debugPrint('First time opening dashboard in this session, loading interstitial ad...');
      _loadInterstitialAd();
    } else {
      debugPrint('Interstitial ad already shown this session, skipping...');
    }
  }

  void _saveInterstitialShownFlag() {
    _interstitialShownThisSession = true;
    debugPrint('Interstitial ad session flag saved successfully.');
  }

  void _loadAd() async {
    final size = await AdSize.getAnchoredAdaptiveBannerAdSize(
      Orientation.portrait,
      MediaQuery.sizeOf(context).width.truncate(),
    );

    if (size == null) return;

    BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint("Banner Ad was loaded.");
          if (mounted) {
            setState(() {
              _bannerAd = ad as BannerAd;
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint("Banner Ad failed to load with error: $err");
          ad.dispose();
        },
        onAdOpened: (Ad ad) => debugPrint("Banner Ad was opened."),
        onAdClosed: (Ad ad) => debugPrint("Banner Ad was closed."),
        onAdImpression: (Ad ad) => debugPrint("Banner Ad recorded an impression."),
        onAdClicked: (Ad ad) => debugPrint("Banner Ad was clicked."),
        onAdWillDismissScreen: (Ad ad) => debugPrint("Banner Ad will be dismissed."),
      ),
    ).load();
  }

  void _loadInterstitialAd() {
    final adUnitId = Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/1033173712'
        : 'ca-app-pub-3940256099942544/4411468910';

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          debugPrint('Interstitial Ad was loaded successfully.');
          _interstitialAd = ad;
          _showInterstitialAd();
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('Interstitial Ad failed to load: $error');
          // Save flag even if ad failed to prevent continuous retry
          _saveInterstitialShownFlag();
        },
      ),
    );
  }

  void _showInterstitialAd() {
    if (_interstitialAd == null) return;

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('Interstitial Ad showed full screen content.');
        // Save flag when ad is successfully shown
        _saveInterstitialShownFlag();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        debugPrint('Interstitial Ad failed to show: $err');
        ad.dispose();
        _interstitialAd = null;
        // Save flag even if show failed
        _saveInterstitialShownFlag();
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('Interstitial Ad was dismissed by user.');
        ad.dispose();
        _interstitialAd = null;
      },
      onAdImpression: (ad) {
        debugPrint('Interstitial Ad recorded an impression.');
      },
      onAdClicked: (ad) {
        debugPrint('Interstitial Ad was clicked.');
      },
    );

    _interstitialAd!.show();
  }

  bool isScanning = false;

  String status = "";
  int currentArticle = 0;
  ScanResult? scanResult;

  Future<void> runAutoScan(Duration duration) async {
    setState(() {
      isScanning = true;
      status = "Menganalisis keseimbangan postur...";
    });

    await Future.delayed(duration);

    setState(() {
      scanResult = ScanResult(
        tilt: 3.2,
        pelvis: "Seimbang",
        curve: "Kanan",
        confidence: 92,
        uncertainty: 8,
      );

      isScanning = false;
    });
  }

  final artikelController = PageController(viewportFraction: 0.88);
  final infoController = PageController(viewportFraction: 0.84);

  final scrollController = ScrollController();

  final artikelKey = GlobalKey();
  final infoKey = GlobalKey();
  final funKey = GlobalKey();

  final artikelImages = const [
    'assets/images/article1.png',
    'assets/images/article2.png',
    'assets/images/article3.png',
  ];

  final infoImages = const [
    'assets/images/img_infographic_gejala.png',
    'assets/images/img_infographic_info.png',
    'assets/images/img_infographic_posture.png',
  ];

  @override
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    artikelController.dispose();
    infoController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void scrollTo(GlobalKey key) {
    final c = key.currentContext;

    if (c != null) {
      Scrollable.ensureVisible(
        c,
        duration: const Duration(milliseconds: 650),
        alignment: .05,
        curve: Curves.easeInOut,
      );
    }
  }

  void logout() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: SizedBox(
          height: 170,
          child: Column(
            children: [
              const SizedBox(height: 22),
              const Text(
                'Logout dari akun\nAnda?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              const Divider(height: 1),
              InkWell(
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  await GoogleSignIn().signOut();

                  if (!mounted) return;

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (r) => false,
                  );
                },
                child: const SizedBox(
                  height: 48,
                  child: Center(
                    child: Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: const SizedBox(
                  height: 48,
                  child: Center(
                    child: Text(
                      'Batalkan',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget sectionTitle(String t) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xffc3c4ff),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget chip(String t, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xffb5c8ff)),
        ),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget artikelSlider() {
    return Column(
      children: [
        SizedBox(
          height: 360,
          child: PageView.builder(
            controller: artikelController,
            itemCount: artikelImages.length,
            itemBuilder: (_, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                ),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ArticleDetailPage(
                          articleIndex: index + 1,
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      artikelImages[index],
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        SmoothPageIndicator(
          controller: artikelController,
          count: artikelImages.length,
          effect: const WormEffect(
            dotHeight: 10,
            dotWidth: 10,
          ),
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget infographicSlider() {
    return Column(
      children: [
        SizedBox(
          height: 280,
          child: PageView.builder(
            controller: infoController,
            itemCount: infoImages.length,
            itemBuilder: (_, i) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    infoImages[i],
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        SmoothPageIndicator(
          controller: infoController,
          count: infoImages.length,
          effect: const WormEffect(
            dotHeight: 10,
            dotWidth: 10,
          ),
        ),
      ],
    );
  }

  Future<void> exportPDF() async {
    if (scanResult == null) return;

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            children: [
              pw.Text(
                "Ringkasan Analisis Postur",
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text("Kemiringan: ${scanResult!.tilt}"),
              pw.Text("Keseimbangan: ${scanResult!.pelvis}"),
              pw.Text("Postur Dominan: ${scanResult!.curve}"),
              pw.Text("Tingkat Keyakinan Analisis: ${scanResult!.confidence}%"),
              pw.SizedBox(height: 15),
              pw.Text(
                "Hasil ini bersifat informatif dan digunakan untuk edukasi postur.",
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Widget funfact() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.asset(
          'assets/images/img_funfact_scoliosis.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_bannerAd != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: SizedBox(
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),
            ),
          const AppBottomNav(currentIndex: 0),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatBotPage()),
          );
        },
        backgroundColor: AppColors.blue,
        child: Image.asset(
          'assets/images/Chat Bot (2).png',
          width: 30,
          height: 30,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.smart_toy,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xffE7EDFF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "Mode Edukasi",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChatBotPage()),
                      );
                    },
                    icon: Image.asset(
                      'assets/images/Chat Bot (2).png',
                      width: 28,
                      height: 28,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.smart_toy,
                        color: AppColors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: logout,
                    icon: const Icon(
                      Icons.logout,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xffDCE6FF),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    const Text(
                      "📖 Edukasi Skoliosis",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        chip("Artikel", () => scrollTo(artikelKey)),
                        chip("Infografis", () => scrollTo(infoKey)),
                        chip("Funfact", () => scrollTo(funKey)),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 35),
              Container(
                key: artikelKey,
                child: sectionTitle("Artikel"),
              ),
              const SizedBox(height: 15),
              artikelSlider(),
              const SizedBox(height: 35),
              Container(
                key: infoKey,
                child: sectionTitle("Infografis"),
              ),
              const SizedBox(height: 15),
              infographicSlider(),
              const SizedBox(height: 35),
              Container(
                key: funKey,
                child: sectionTitle("Funfact"),
              ),
              const SizedBox(height: 15),
              funfact(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  NativeAd? _nativeAd;
  bool _nativeAdIsLoaded = false;
  final String _nativeAdUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/2247696110'
      : 'ca-app-pub-3940256099942544/3986624511';

  void _loadNativeAd() {
    _nativeAd = NativeAd(
      adUnitId: _nativeAdUnitId,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint('Native Ad loaded successfully.');
          setState(() {
            _nativeAdIsLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Native Ad failed to load: $error');
          ad.dispose();
        },
        onAdClicked: (ad) {
          debugPrint('Native Ad was clicked.');
        },
        onAdImpression: (ad) {
          debugPrint('Native Ad recorded an impression.');
        },
        onAdClosed: (ad) {
          debugPrint('Native Ad was closed.');
        },
        onAdOpened: (ad) {
          debugPrint('Native Ad was opened.');
        },
        onAdWillDismissScreen: (ad) {
          debugPrint('Native Ad will be dismissed.');
        },
      ),
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: Colors.white,
        cornerRadius: 16.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: AppColors.blue,
          style: NativeTemplateFontStyle.bold,
          size: 14.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.black87,
          style: NativeTemplateFontStyle.bold,
          size: 15.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.black54,
          style: NativeTemplateFontStyle.normal,
          size: 13.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.black45,
          style: NativeTemplateFontStyle.normal,
          size: 12.0,
        ),
      ),
    )..load();
  }

  CameraController? controller;

  String result = "Belum ada analisis";
  Map<String, dynamic>? lastScanResult;

  double calculateAngle(
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
    return atan2(
          y2 - y1,
          x2 - x1,
        ) *
        180 /
        pi;
  }

  bool loading = true;
  bool analyzing = false;

  final poseDetector = PoseDetector(
    options: PoseDetectorOptions(),
  );
  @override
  void initState() {
    super.initState();
    _loadNativeAd();
    initCamera();
  }

  Future<String?> uploadScanImage(File file) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) return null;

      final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";

      final ref = FirebaseStorage.instance
          .ref()
          .child("scan_images")
          .child(uid)
          .child(fileName);

      await ref.putFile(file);

      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("UPLOAD ERROR: $e");
      return null;
    }
  }

  Future<void> initCamera() async {
    if (!await ensureCameraPermission(context: context)) {
      if (!mounted) return;
      setState(() {
        result = "Izin kamera ditolak";
        loading = false;
      });
      return;
    }

    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          result = "Kamera tidak ditemukan";
          loading = false;
        });
        return;
      }

      controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
      );

      await controller!.initialize();

      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        result = "Gagal membuka kamera";
        loading = false;
      });
    }
  }

  Future<void> analyzePose() async {
    if (controller == null || !controller!.value.isInitialized) return;

    try {
      setState(() {
        analyzing = true;
        result = "Mengambil gambar...";
      });

      final XFile image = await controller!.takePicture();
      final imageFile = File(image.path);

      final imageUrl = await uploadScanImage(imageFile);

      final inputImage = InputImage.fromFile(imageFile);

      final poses = await poseDetector.processImage(inputImage);
      if (!mounted) return;
      if (poses.isEmpty) {
        setState(() {
          result = "Tubuh tidak terdeteksi";
          analyzing = false;
        });
        return;
      }

      final pose = poses.first;

      final qualityScore = pose.landmarks.length;

      final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
      final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

      final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
      final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

      final nose = pose.landmarks[PoseLandmarkType.nose];

      final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
      final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];

      if (leftShoulder == null ||
          rightShoulder == null ||
          leftHip == null ||
          rightHip == null ||
          nose == null ||
          leftKnee == null ||
          rightKnee == null) {
        setState(() {
          result = "Posisikan seluruh tubuh di dalam kamera";
          analyzing = false;
        });
        return;
      }

      final shoulderAngle = calculateAngle(
        leftShoulder.x,
        leftShoulder.y,
        rightShoulder.x,
        rightShoulder.y,
      );

      final hipAngle = calculateAngle(
        leftHip.x,
        leftHip.y,
        rightHip.x,
        rightHip.y,
      );

      final shoulderDiff = shoulderAngle.abs();
      final hipDiff = hipAngle.abs();

      final bodyCenterX = (leftHip.x + rightHip.x) / 2;

      final headOffset = (nose.x - bodyCenterX).abs();

      String pemeriksaan;

      if (shoulderDiff < 5 && hipDiff < 5 && headOffset < 30) {
        pemeriksaan = "Postur Relatif Normal";
      } else if (shoulderDiff < 10 && hipDiff < 10) {
        pemeriksaan = "Indikasi Asimetri Ringan";
      } else if (shoulderDiff < 20 && hipDiff < 20) {
        pemeriksaan = "Indikasi Asimetri Sedang";
      } else {
        pemeriksaan = "Indikasi Kemiringan Signifikan";
      }

      double score = 100 - ((shoulderDiff * 2) + hipDiff + (headOffset / 5));

      score = score.clamp(0, 100);

      String recommendation;

      if (score >= 85) {
        recommendation = "Postur tubuh baik. Pertahankan kebiasaan yang sehat.";
      } else if (score >= 70) {
        recommendation =
            "Terdapat sedikit ketidakseimbangan. Perhatikan posisi duduk, berdiri, dan lakukan peregangan secara rutin.";
      } else if (score >= 60) {
        recommendation =
            "Terlihat adanya asimetri postur tingkat sedang. Disarankan melakukan latihan koreksi postur dan evaluasi berkala.";
      } else {
        recommendation =
            "Terdeteksi ketidakseimbangan postural yang cukup signifikan. Pertimbangkan konsultasi dengan tenaga kesehatan atau fisioterapis.";
      }

      await saveScanResult(
        pemeriksaan,
        score,
        shoulderDiff,
        hipDiff,
        headOffset,
        qualityScore,
        recommendation,
        imageUrl,
      );

      if (!mounted) return;

      setState(() {
        lastScanResult = {
          'pemeriksaan': pemeriksaan,
          'score': score,
          'shoulderDiff': shoulderDiff,
          'hipDiff': hipDiff,
          'headOffset': headOffset,
          'qualityScore': qualityScore,
          'recommendation': recommendation,
          'imageUrl': imageUrl,
          'createdAt': Timestamp.now(),
        };

        result = "HASIL ANALISIS POSTUR\n\n"
            "Status : $pemeriksaan\n\n"
            "Skor Postur : ${score.toStringAsFixed(0)}/100\n\n"
            "Kemiringan Bahu : ${shoulderDiff.toStringAsFixed(1)}°\n"
            "Kemiringan Pinggul : ${hipDiff.toStringAsFixed(1)}°\n"
            "Deviasi Kepala : ${headOffset.toStringAsFixed(1)} px\n\n"
            "Rekomendasi:\n$recommendation";

        analyzing = false;
      });

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => ScanResultModal(
          data: lastScanResult!,
          onScanAgain: () {},
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        result = "Error: $e";
        analyzing = false;
      });
    }
  }

  Future<void> saveScanResult(
    String pemeriksaan,
    double score,
    double shoulderDiff,
    double hipDiff,
    double headOffset,
    int qualityScore,
    String recommendation,
    String? imageUrl,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      // 1. Simpan ke scan_history (untuk riwayat pengguna)
      await FirebaseFirestore.instance.collection('scan_history').add({
        'uid': user.uid,
        'pemeriksaan': pemeriksaan,
        'score': score,
        'shoulderDiff': shoulderDiff,
        'hipDiff': hipDiff,
        'headOffset': headOffset,
        'recommendation': recommendation,
        'imageUrl': imageUrl,
        'appVersion': '1.0.0',
        'qualityScore': qualityScore,
        'createdAt': Timestamp.now(),
      });

      // 2. Simpan ke scan_results (untuk Dashboard Admin)
      await FirebaseFirestore.instance.collection('scan_results').add({
        'uid': user.uid,
        'status': pemeriksaan,
        'recommendation': recommendation,
        'createdAt': Timestamp.now(),
        'result': {
          'confidence': score,
          'curve': shoulderDiff > 0 ? 'Indikasi asimetri kanan' : 'Indikasi asimetri kiri',
          'pelvis': hipDiff < 5 ? 'Seimbang' : 'Sedikit miring',
          'qualityPct': 100,
          'tilt': shoulderDiff,
          'uncertainty': 100 - score,
          'viewsIncluded': ['back'],
        },
        'profile': {
          'name': user.displayName ?? 'User',
          'gender': '-',
          'age': '-',
          'height': '-',
          'weight': '-',
          'note': '-',
        },
      });
    } catch (e) {
      debugPrint('SAVE ERROR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scanner AI"),
        centerTitle: true,
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: controller == null
                        ? const SizedBox(
                            height: 220,
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : AspectRatio(
                            aspectRatio: controller!.value.aspectRatio,
                            child: CameraPreview(
                              controller!,
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),
                  MainButton(
                    text: analyzing ? "Menganalisis..." : "Analisis Postur",
                    onTap: () {
                      if (!analyzing) {
                        analyzePose();
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.analytics_outlined,
                            size: 40,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            result,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_nativeAdIsLoaded && _nativeAd != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 90,
                          child: AdWidget(ad: _nativeAd!),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    controller?.dispose();
    poseDetector.close();
    super.dispose();
  }
}

class ScanDetailPage extends StatelessWidget {
  final Map<String, dynamic> data;

  const ScanDetailPage({
    super.key,
    required this.data,
  });

  Future<void> exportPdf(BuildContext context) async {
    final pdf = pw.Document();

    final score = (data['score'] as num?) ?? 0;
    final shoulderDiff = (data['shoulderDiff'] as num?) ?? 0;
    final hipDiff = (data['hipDiff'] as num?) ?? 0;
    final headOffset = (data['headOffset'] as num?) ?? 0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "SCOLIX AI",
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  "Laporan Hasil Pemeriksaan Postur",
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Divider(),
                pw.Text(
                  "Hasil Pemeriksaan : ${data['pemeriksaan'] ?? '-'}",
                ),
                pw.Text(
                  "Skor Postur : ${score.toStringAsFixed(0)}/100",
                ),
                pw.Text(
                  "Kemiringan Bahu : ${shoulderDiff.toStringAsFixed(1)}°",
                ),
                pw.Text(
                  "Kemiringan Pinggul : ${hipDiff.toStringAsFixed(1)}°",
                ),
                pw.Text(
                  "Deviasi Kepala : ${headOffset.toStringAsFixed(1)} px",
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  "Rekomendasi",
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  data['recommendation'] ?? '-',
                ),
                pw.SizedBox(height: 30),
                pw.Text(
                  "Catatan: Hasil ini bersifat informatif dan bukan pemeriksaan medis.",
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final score = (data['score'] as num?) ?? 0;
    final shoulderDiff = (data['shoulderDiff'] as num?) ?? 0;
    final hipDiff = (data['hipDiff'] as num?) ?? 0;
    final headOffset = (data['headOffset'] as num?) ?? 0;
    final qualityScore = (data['qualityScore'] as num?) ?? 0;

    final createdAt = data['createdAt'] as Timestamp?;
    final date = createdAt?.toDate();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detail Scan"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data['imageUrl'] != null &&
                    data['imageUrl'].toString().isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      data['imageUrl'],
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          return child;
                        }

                        return const SizedBox(
                          height: 220,
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) {
                        return Container(
                          height: 220,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 60,
                          ),
                        );
                      },
                    ),
                  ),
                if (data['imageUrl'] != null &&
                    data['imageUrl'].toString().isNotEmpty)
                  const SizedBox(height: 20),
                const Center(
                  child: Icon(
                    Icons.analytics_outlined,
                    size: 60,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 20),
                if (date != null) ...[
                  const Text(
                    "Tanggal Scan",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    "${date.day}/${date.month}/${date.year} "
                    "${date.hour.toString().padLeft(2, '0')}:"
                    "${date.minute.toString().padLeft(2, '0')}",
                  ),
                  const Divider(),
                ],
                const Text(
                  "Hasil Pemeriksaan",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text("${data['pemeriksaan'] ?? '-'}"),
                const Divider(),
                const Text(
                  "Skor Postur",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text("${score.toStringAsFixed(0)}/100"),
                const Divider(),
                const Text(
                  "Kemiringan Bahu",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text("${shoulderDiff.toStringAsFixed(1)}°"),
                const SizedBox(height: 16),
                const Text(
                  "Kemiringan Pinggul",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text("${hipDiff.toStringAsFixed(1)}°"),
                const Divider(),
                const Text(
                  "Deviasi Kepala",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text("${headOffset.toStringAsFixed(1)} px"),
                const Divider(),
                const Text(
                  "Kualitas Deteksi",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  "${qualityScore.toInt()} / 33 landmark terdeteksi",
                ),
                const Divider(),
                const Text(
                  "Rekomendasi",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  "${data['recommendation'] ?? '-'}",
                ),
                const SizedBox(height: 20),
                const Text(
                  "Catatan: Hasil pemeriksaan ini bersifat informatif dan bukan pemeriksaan medis.",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text(
                      "Export PDF",
                    ),
                    onPressed: () {
                      exportPdf(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FullImagePage extends StatelessWidget {
  final String imageUrl;

  const FullImagePage({
    super.key,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;

              return const Center(
                child: CircularProgressIndicator(),
              );
            },
            errorBuilder: (_, __, ___) {
              return const Icon(
                Icons.broken_image,
                color: Colors.white,
                size: 80,
              );
            },
          ),
        ),
      ),
    );
  }
}

class ArticleDetailPage extends StatelessWidget {
  final int articleIndex;

  const ArticleDetailPage({super.key, required this.articleIndex});

  String get title {
    if (articleIndex == 1) return 'Panduan Postur Tubuh';
    if (articleIndex == 2) return 'Keseimbangan Bahu dan Punggung';
    return 'Keseimbangan Bahu dan Punggung';
  }

  String get url {
    if (articleIndex == 1) {
      return 'https://www.klikdokter.com/penyakit/masalah-tulang/skoliosis?utm_source=chatgpt.com';
    }
    if (articleIndex == 2) {
      return 'https://www.alodokter.com/skoliosis?utm_source=chatgpt.com';
    }
    return 'https://health.kompas.com/penyakit/read/2021/11/03/060000468/skoliosis?lgn_method=google&google_btn=onetap&utm_source=chatgpt.com';
  }

  List<String> get points {
    if (articleIndex == 1) {
      return [
        'Apa yang dimaksud dengan skoliosis?',
        'Bagaimana bentuk kelengkungan tulang belakang pada skoliosis?',
        'Apa saja jenis-jenis skoliosis?',
      ];
    }

    if (articleIndex == 2) {
      return [
        'Apa penyebab skoliosis?',
        'Gejala apa yang perlu diwaspadai?',
        'Kapan harus konsultasi ke dokter?',
      ];
    }

    return [
      'Bagaimana tips menjaga postur yang baik?',
      'Apa langkah pencegahan skoliosis?',
      'Kapan pemeriksaan medis diperlukan?',
    ];
  }

  String get bodyText {
    if (articleIndex == 1) {
      return 'Skoliosis merupakan kondisi ketika tulang belakang melengkung ke satu sisi. Normalnya, jika dilihat dari belakang tulang belakang akan terlihat lurus. Namun, pada skoliosis tulang belakang dapat tampak melengkung seperti huruf C atau S.';
    }

    if (articleIndex == 2) {
      return 'Skoliosis dapat terjadi karena faktor bawaan, gangguan saraf dan otot, cedera, kebiasaan postur, atau penyebab yang tidak diketahui secara pasti. Gejala yang sering terlihat adalah bahu tidak sejajar, pinggul tidak rata, dan tubuh tampak condong ke satu sisi.';
    }

    return 'Tips Menjaga Postur dapat dilakukan dengan memperhatikan postur tubuh, posisi bahu, pinggul, dan bentuk punggung saat berdiri atau membungkuk. Pencegahan dapat dibantu dengan menjaga postur, olahraga teratur, dan pemeriksaan bila ada keluhan.';
  }

  List<String> get symptoms {
    if (articleIndex == 1) {
      return [
        'Jaga posisi duduk tetap nyaman',
        'Gunakan meja dan kursi ergonomis',
        'Lakukan peregangan ringan',
        'Perhatikan keseimbangan tubuh',
      ];
    }

    if (articleIndex == 2) {
      return [
        'Nyeri punggung atau cepat lelah saat berdiri lama',
        'Bahu kanan dan kiri tampak tidak sama tinggi',
        'Pakaian terlihat tidak seimbang saat dikenakan',
        'Tubuh tampak miring ketika berdiri tegak',
      ];
    }

    return [
      'Lakukan pemeriksaan postur secara berkala',
      'Jaga posisi duduk dan berdiri tetap tegak',
      'Olahraga ringan untuk menjaga fleksibilitas tubuh',
      'Segera konsultasi jika tampak kelengkungan yang jelas',
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff8f8ff),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Artikel',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.softPanel,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.arrow_back, size: 34),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Dalam Artikel ini',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 54),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: points
                            .map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Text(
                                  '• $e',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 5,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            bodyText,
                            style: const TextStyle(
                              fontSize: 17,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xffb9c4ff),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('💡', style: TextStyle(fontSize: 34)),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Skoliosis ringan mungkin tidak menimbulkan gejala, tetapi kasus yang lebih parah dapat memengaruhi postur tubuh dan kualitas hidup.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      height: 1.35,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Tips Menjaga Postur',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...symptoms.map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '• $e',
                                style: const TextStyle(
                                  fontSize: 16.5,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Sumber dan Baca Selengkapnya',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Center(
                            child: Text(
                              'Artikel ini dirangkum dari sumber terpercaya',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 15),
                            ),
                          ),
                          const SizedBox(height: 14),
                          GestureDetector(
                            onTap: () => openUrl(context, url),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xffc9d2ff),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Baca Artikel Lengkap di website',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Klik Untuk Baca',
                                    style: TextStyle(
                                      color: AppColors.blue,
                                      decoration: TextDecoration.underline,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UserData {
  final String name;
  final String age;
  final String gender;
  final String height;
  final String weight;
  final String postureNote;
  final String referencePhoto;

  const UserData({
    required this.name,
    required this.age,
    required this.gender,
    required this.height,
    required this.weight,
    required this.postureNote,
    required this.referencePhoto,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'age': age,
        'gender': gender,
        'height': height,
        'weight': weight,
        'postureNote': postureNote,
        'referencePhoto': referencePhoto,
      };
}

class PoseKeypoint {
  final String name;
  final double x;
  final double y;
  final double score;

  const PoseKeypoint({
    required this.name,
    required this.x,
    required this.y,
    this.score = 1,
  });
}

class ProcessingScreen extends StatefulWidget {
  final Future<void> Function() onComplete;

  const ProcessingScreen({super.key, required this.onComplete});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  double progress = 0.0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 250), (t) {
      if (!mounted) return;
      setState(() {
        progress += 0.08;
        if (progress >= 1) progress = 1;
      });
      if (progress >= 1) {
        t.cancel();
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Memproses analisis postur...',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 14),
            Text('${(progress * 100).round()}%'),
            const SizedBox(height: 10),
            const Text(
              'Memeriksa keseimbangan dan pola postur tubuh...',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class ScanResultModal extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onScanAgain;

  const ScanResultModal({
    super.key,
    required this.data,
    required this.onScanAgain,
  });

  Widget card(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pemeriksaan = data['pemeriksaan'] ?? '-';
    final score = (data['score'] ?? 0).toDouble();
    final shoulderDiff = (data['shoulderDiff'] ?? 0).toDouble();
    final hipDiff = (data['hipDiff'] ?? 0).toDouble();
    final headOffset = (data['headOffset'] ?? 0).toDouble();
    final recommendation = data['recommendation'] ?? '-';

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: score >= 85
                    ? Colors.green.shade100
                    : score >= 70
                        ? Colors.orange.shade100
                        : Colors.red.shade100,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    score >= 85
                        ? "✅"
                        : score >= 70
                            ? "⚠️"
                            : "❌",
                    style: const TextStyle(fontSize: 38),
                  ),
                  Text(
                    pemeriksaan,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Skor Postur ${score.toStringAsFixed(0)}/100",
                    style: const TextStyle(
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.2,
              children: [
                card(
                  "Kemiringan Bahu",
                  "${shoulderDiff.toStringAsFixed(1)}°",
                ),
                card(
                  "Kemiringan Pinggul",
                  "${hipDiff.toStringAsFixed(1)}°",
                ),
                card(
                  "Deviasi Kepala",
                  "${headOffset.toStringAsFixed(1)} px",
                ),
                card(
                  "Status",
                  pemeriksaan,
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              "Rekomendasi",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              recommendation,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              "Catatan: hasil bersifat informatif untuk edukasi postur.",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 18),
            MainButton(
              text: "Scan Ulang",
              onTap: () {
                Navigator.pop(context);
                onScanAgain();
              },
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Tutup"),
            ),
          ],
        ),
      ),
    );
  }
}

class SpineGuidePainter extends CustomPainter {
  final double tilt;

  SpineGuidePainter({required this.tilt});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .12);
    final paint = Paint()
      ..color = AppColors.blue
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(center.dx, center.dy);
    path.cubicTo(
      center.dx - tilt * 2,
      size.height * .35,
      center.dx + tilt * 2,
      size.height * .65,
      center.dx,
      size.height * .9,
    );
    canvas.drawPath(path, paint);

    final heat = Paint()
      ..color = Colors.red.withValues(alpha: 0.20)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(center.dx + tilt * 3, size.height * .45),
      35,
      heat,
    );
  }

  @override
  bool shouldRepaint(covariant SpineGuidePainter oldDelegate) =>
      oldDelegate.tilt != tilt;
}

class ScanResult {
  final double tilt;
  final String pelvis;
  final String curve;
  final double confidence;
  final double uncertainty;

  ScanResult({
    required this.tilt,
    required this.pelvis,
    required this.curve,
    required this.confidence,
    required this.uncertainty,
  });
}

// Minimal model types referenced by other parts of this large file.
// They are required for compilation, even if not fully used by the UI.
class ScanRecord {
  final String status;
  final ScanResult result;
  final String recommendation;

  ScanRecord({
    required this.status,
    required this.result,
    required this.recommendation,
  });
}

class ScanRepository {
  // In this app, scan history is stored to Firestore.
  // For local usage by the chatbot fallback, keep an in-memory list.
  static final List<ScanRecord> histories = <ScanRecord>[];
}

class UserDataPage extends StatefulWidget {
  const UserDataPage({super.key});

  @override
  State<UserDataPage> createState() => _UserDataPageState();
}

class _UserDataPageState extends State<UserDataPage> {
  final formKey = GlobalKey<FormState>();
  final scrollController = ScrollController();

  final nama = TextEditingController();
  final gender = TextEditingController();
  final umur = TextEditingController();
  final tinggi = TextEditingController();
  final berat = TextEditingController();
  bool isScanning = false;

  String status = "";

  ScanResult? scanResult;

  late PoseDetector poseDetector;
  CameraController? cam;
  bool active = false;
  bool scanning = false;
  String selectedGender = 'Pria';
  ScanRecord? last;
  String referencePhoto = 'Belum ada foto referensi';

  NativeAd? _nativeAd;
  bool _nativeAdIsLoaded = false;
  final String _nativeAdUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/2247696110'
      : 'ca-app-pub-3940256099942544/3986624511';

  void _loadNativeAd() {
    _nativeAd = NativeAd(
      adUnitId: _nativeAdUnitId,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint('Native Ad loaded successfully.');
          setState(() {
            _nativeAdIsLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Native Ad failed to load: $error');
          ad.dispose();
        },
        onAdClicked: (ad) {
          debugPrint('Native Ad was clicked.');
        },
        onAdImpression: (ad) {
          debugPrint('Native Ad recorded an impression.');
        },
        onAdClosed: (ad) {
          debugPrint('Native Ad was closed.');
        },
        onAdOpened: (ad) {
          debugPrint('Native Ad was opened.');
        },
        onAdWillDismissScreen: (ad) {
          debugPrint('Native Ad will be dismissed.');
        },
      ),
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: Colors.white,
        cornerRadius: 16.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: AppColors.blue,
          style: NativeTemplateFontStyle.bold,
          size: 14.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.black87,
          style: NativeTemplateFontStyle.bold,
          size: 15.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.black54,
          style: NativeTemplateFontStyle.normal,
          size: 13.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.black45,
          style: NativeTemplateFontStyle.normal,
          size: 12.0,
        ),
      ),
    )..load();
  }

  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;
  final String _rewardedAdUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/5224354917'
      : 'ca-app-pub-3940256099942544/1712485313';

  void _loadRewardedAd() {
    if (_isRewardedAdLoading) return;
    _isRewardedAdLoading = true;
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('Rewarded Ad loaded successfully.');
          _rewardedAd = ad;
          _isRewardedAdLoading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded Ad failed to load: $error');
          _rewardedAd = null;
          _isRewardedAdLoading = false;
        },
      ),
    );
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    _rewardedAd?.dispose();
    cam?.dispose();
    nama.dispose();
    gender.dispose();
    umur.dispose();
    tinggi.dispose();
    berat.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadRewardedAd();
    _loadNativeAd();

    poseDetector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
    );
  }

  double calculateTilt(PoseLandmark leftShoulder, PoseLandmark rightShoulder) {
    double dx = rightShoulder.x - leftShoulder.x;

    double dy = rightShoulder.y - leftShoulder.y;

    return math.atan2(dy, dx) * 180 / math.pi;
  }

  Future<ScanResult> processPose() async {
    final file = await cam!.takePicture();

    final inputImage = InputImage.fromFilePath(file.path);

    final poses = await poseDetector.processImage(inputImage);

    if (poses.isEmpty) {
      return ScanResult(
        tilt: 0,
        pelvis: "Tidak ada",
        curve: "Tidak ada",
        confidence: 0,
        uncertainty: 100,
      );
    }

    final pose = poses.first;

    final left = pose.landmarks[PoseLandmarkType.leftShoulder];

    final right = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (left == null || right == null) {
      return ScanResult(
        tilt: 0,
        pelvis: "Tidak terdeteksi",
        curve: "Tidak ada",
        confidence: 0,
        uncertainty: 100,
      );
    }

    double tilt = calculateTilt(left, right);

    return ScanResult(
      tilt: tilt.abs(),
      pelvis: "Seimbang",
      curve: tilt > 0 ? "Kanan" : "Kiri",
      confidence: 92,
      uncertainty: 8,
    );
  }

  Future<void> runAutoScan(Duration duration) async {
    setState(() {
      isScanning = true;

      status = "Menganalisis keseimbangan postur...";
    });

    await Future.delayed(duration);

    final result = await processPose();

    setState(() {
      scanResult = result;

      isScanning = false;
    });
  }

  Future<void> openCamera() async {
    if (!await ensureCameraPermission(context: context)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin kamera ditolak')),
        );
      }
      return;
    }

    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kamera tidak ditemukan')),
          );
        }
        return;
      }

      await cam?.dispose();
      cam = CameraController(
        cams.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await cam!.initialize();
      if (mounted) setState(() => active = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kamera tidak dapat dibuka')),
        );
      }
    }
  }

  UserData profile() => UserData(
        name: nama.text.trim().isEmpty ? 'Pengguna Demo' : nama.text.trim(),
        age: umur.text.trim().isEmpty ? '0' : umur.text.trim(),
        gender: selectedGender,
        height: tinggi.text.trim().isEmpty ? '-' : tinggi.text.trim(),
        weight: berat.text.trim().isEmpty ? '-' : berat.text.trim(),
        postureNote: '-',
        referencePhoto: referencePhoto,
      );

  Future<void> saveScanResultToFirestore(
    String pemeriksaan,
    double score,
    double shoulderDiff,
    double hipDiff,
    double headOffset,
    String recommendation,
    String? imageUrl,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. Simpan ke scan_history (untuk riwayat pengguna)
      await FirebaseFirestore.instance.collection('scan_history').add({
        'uid': user.uid,
        'pemeriksaan': pemeriksaan,
        'score': score,
        'shoulderDiff': shoulderDiff,
        'hipDiff': hipDiff,
        'headOffset': headOffset,
        'recommendation': recommendation,
        'imageUrl': imageUrl,
        'appVersion': '1.0.0',
        'qualityScore': pose?.landmarks.length ?? 0,
        'createdAt': Timestamp.now(),
      });

      // 2. Simpan ke scan_results (untuk Dashboard Admin)
      await FirebaseFirestore.instance.collection('scan_results').add({
        'uid': user.uid,
        'status': pemeriksaan,
        'recommendation': recommendation,
        'createdAt': Timestamp.now(),
        'result': {
          'confidence': score,
          'curve': shoulderDiff > 0 ? 'Indikasi asimetri kanan' : 'Indikasi asimetri kiri',
          'pelvis': hipDiff < 5 ? 'Seimbang' : 'Sedikit miring',
          'qualityPct': 100,
          'tilt': shoulderDiff,
          'uncertainty': 100 - score,
          'viewsIncluded': ['back'],
        },
        'profile': {
          'name': nama.text.trim().isEmpty ? (user.displayName ?? 'User') : nama.text.trim(),
          'gender': selectedGender,
          'age': umur.text.trim(),
          'height': tinggi.text.trim(),
          'weight': berat.text.trim(),
          'note': '-',
        },
      });

      // Update in-memory cache untuk chatbot fallback
      ScanRepository.histories.insert(
        0,
        ScanRecord(
          status: pemeriksaan,
          result: ScanResult(
            tilt: shoulderDiff,
            pelvis: hipDiff < 5 ? 'Seimbang' : 'Tidak Seimbang',
            curve: shoulderDiff > 0 ? 'Kanan' : 'Kiri',
            confidence: score,
            uncertainty: 100 - score,
          ),
          recommendation: recommendation,
        ),
      );
    } catch (e) {
      debugPrint('SAVE ERROR: $e');
    }
  }

  Pose? pose;

  Future<void> runScan() async {
    if (!formKey.currentState!.validate()) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      return;
    }

    // Pastikan kamera sudah aktif
    if (!active || cam == null || !cam!.value.isInitialized) {
      await openCamera();
      if (!active || cam == null || !cam!.value.isInitialized) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kamera belum siap. Coba tekan tombol kamera dulu.')),
          );
        }
        return;
      }
    }

    if (!mounted) return;

    _showAdConfirmationDialog();
  }

  void _showAdConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: const [
              Icon(Icons.ondemand_video, color: AppColors.blue),
              SizedBox(width: 10),
              Text(
                'Nonton Video',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: const Text(
            'Untuk memulai pemindaian AI postur tubuh, silakan tonton iklan video singkat terlebih dahulu sampai selesai.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Batal',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showRewardedAdAndScan();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Tonton & Mulai'),
            ),
          ],
        );
      },
    );
  }

  void _showRewardedAdAndScan() {
    if (_rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          debugPrint('Rewarded Ad: showed full screen content.');
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          debugPrint('Rewarded Ad failed to show: $err');
          ad.dispose();
          _rewardedAd = null;
          _loadRewardedAd(); // load baru untuk scan berikutnya
          // Fallback: tetap jalankan scan jika gagal tayang agar pengguna tidak terblokir
          _executeActualScan();
        },
        onAdDismissedFullScreenContent: (ad) {
          debugPrint('Rewarded Ad was dismissed.');
          ad.dispose();
          _rewardedAd = null;
          _loadRewardedAd(); // load baru untuk scan berikutnya
        },
      );

      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem rewardItem) {
          debugPrint('User earned reward: ${rewardItem.amount}');
          _executeActualScan();
        },
      );
    } else {
      debugPrint('Rewarded Ad not ready, proceeding with scan directly.');
      _executeActualScan();
      _loadRewardedAd(); // coba load lagi
    }
  }

  Future<void> _executeActualScan() async {
    if (!mounted) return;

    setState(() {
      scanning = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProcessingScreen(
        onComplete: () async {
          try {
            // ---- Jalankan ML Kit Pose Detection ----
            final xFile = await cam!.takePicture();
            final imageFile = File(xFile.path);
            final inputImage = InputImage.fromFile(imageFile);
            final poses = await poseDetector.processImage(inputImage);

            if (!mounted) return;
            Navigator.pop(context); // tutup ProcessingScreen

            if (poses.isEmpty) {
              setState(() => scanning = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tubuh tidak terdeteksi. Pastikan tubuh terlihat jelas di kamera.')),
              );
              return;
            }

            final detectedPose = poses.first;
            pose = detectedPose;

            final leftShoulder = detectedPose.landmarks[PoseLandmarkType.leftShoulder];
            final rightShoulder = detectedPose.landmarks[PoseLandmarkType.rightShoulder];
            final leftHip = detectedPose.landmarks[PoseLandmarkType.leftHip];
            final rightHip = detectedPose.landmarks[PoseLandmarkType.rightHip];
            final nose = detectedPose.landmarks[PoseLandmarkType.nose];

            if (leftShoulder == null || rightShoulder == null ||
                leftHip == null || rightHip == null || nose == null) {
              setState(() => scanning = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Posisikan seluruh tubuh di dalam kamera.')),
              );
              return;
            }

            // Hitung sudut
            final shoulderDiff = (atan2(
              rightShoulder.y - leftShoulder.y,
              rightShoulder.x - leftShoulder.x,
            ) * 180 / pi).abs();

            final hipDiff = (atan2(
              rightHip.y - leftHip.y,
              rightHip.x - leftHip.x,
            ) * 180 / pi).abs();

            final bodyCenterX = (leftHip.x + rightHip.x) / 2;
            final headOffset = (nose.x - bodyCenterX).abs();

            // Tentukan status pemeriksaan
            String pemeriksaan;
            if (shoulderDiff < 5 && hipDiff < 5 && headOffset < 30) {
              pemeriksaan = 'Postur Relatif Normal';
            } else if (shoulderDiff < 10 && hipDiff < 10) {
              pemeriksaan = 'Indikasi Asimetri Ringan';
            } else if (shoulderDiff < 20 && hipDiff < 20) {
              pemeriksaan = 'Indikasi Asimetri Sedang';
            } else {
              pemeriksaan = 'Indikasi Kemiringan Signifikan';
            }

            // Hitung skor
            double score = 100 - ((shoulderDiff * 2) + hipDiff + (headOffset / 5));
            score = score.clamp(0, 100);

            // Rekomendasi berdasarkan skor
            String recommendation;
            if (score >= 85) {
              recommendation = 'Postur tubuh baik. Pertahankan kebiasaan yang sehat.';
            } else if (score >= 70) {
              recommendation = 'Terdapat sedikit ketidakseimbangan. Perhatikan posisi duduk, berdiri, dan lakukan peregangan secara rutin.';
            } else if (score >= 60) {
              recommendation = 'Terlihat adanya asimetri postur tingkat sedang. Disarankan melakukan latihan koreksi postur dan evaluasi berkala.';
            } else {
              recommendation = 'Terdeteksi ketidakseimbangan postural yang cukup signifikan. Pertimbangkan konsultasi dengan tenaga kesehatan atau fisioterapis.';
            }

            // Upload foto dan simpan ke Firestore
            String? imageUrl;
            try {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
                final ref = FirebaseStorage.instance
                    .ref()
                    .child('scan_images')
                    .child(uid)
                    .child(fileName);
                await ref.putFile(imageFile);
                imageUrl = await ref.getDownloadURL();
              }
            } catch (uploadErr) {
              debugPrint('UPLOAD ERROR: $uploadErr');
            }

            // Simpan ke Firestore (akan tampil di Riwayat)
            await saveScanResultToFirestore(
              pemeriksaan,
              score,
              shoulderDiff,
              hipDiff,
              headOffset,
              recommendation,
              imageUrl,
            );

            if (!mounted) return;

            setState(() {
              last = ScanRecord(
                status: pemeriksaan,
                result: ScanResult(
                  tilt: shoulderDiff,
                  pelvis: hipDiff < 5 ? 'Seimbang' : 'Tidak Seimbang',
                  curve: shoulderDiff > 0 ? 'Kanan' : 'Kiri',
                  confidence: score,
                  uncertainty: 100 - score,
                ),
                recommendation: recommendation,
              );
              scanning = false;
            });

            // Tampilkan hasil scan
            showDialog(
              context: context,
              builder: (_) => ScanResultModal(
                data: {
                  'pemeriksaan': pemeriksaan,
                  'score': score,
                  'shoulderDiff': shoulderDiff,
                  'hipDiff': hipDiff,
                  'headOffset': headOffset,
                  'recommendation': recommendation,
                  'imageUrl': imageUrl,
                  'createdAt': Timestamp.now(),
                },
                onScanAgain: () {},
              ),
            );
          } catch (e) {
            if (!mounted) return;

            Navigator.pop(context);

            setState(() {
              scanning = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Scan gagal: $e')),
            );
          }
        },
      ),
    );
  }

  Widget field(
    String l,
    String h,
    TextEditingController c, {
    TextInputType type = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        TextFormField(
          controller: c,
          keyboardType: type,
          validator: (v) {
            if (v == null || v.isEmpty) return '$l wajib diisi';
            if ((l == 'Umur' || l == 'Tinggi Badan' || l == 'Berat Badan') &&
                int.tryParse(v) == null) {
              return '$l harus berupa angka';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: h,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget scanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 30),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xffdde3ff),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          const Text(
            'Berdiri tegak, kamera sejajar punggung',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Silahkan ambil gambar punggung atau bahu anda untuk dianalisis.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 24),
          Container(
            height: 340,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .35),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (active && cam != null && cam!.value.isInitialized)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: CameraPreview(cam!),
                  ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 22,
                  bottom: 22,
                  child: Container(width: 4, color: Colors.white),
                ),
                Positioned(
                  left: 22,
                  right: 22,
                  top: 80,
                  child: Container(height: 4, color: Colors.white),
                ),
                Positioned(
                  left: 22,
                  right: 22,
                  bottom: 80,
                  child: Container(height: 4, color: Colors.white),
                ),
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                ),
                Positioned(left: 48, top: 90, child: corner()),
                Positioned(
                  right: 48,
                  top: 90,
                  child: Transform.rotate(angle: math.pi / 2, child: corner()),
                ),
                Positioned(
                  left: 48,
                  bottom: 90,
                  child: Transform.rotate(angle: -math.pi / 2, child: corner()),
                ),
                Positioned(
                  right: 48,
                  bottom: 90,
                  child: Transform.rotate(angle: math.pi, child: corner()),
                ),
                if (!active)
                  const Text(
                    'Camera Preview',
                    style: TextStyle(
                      color: Colors.black45,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              actionCircle(Icons.photo_library_outlined, () {}),
              actionCircle(Icons.camera_alt, openCamera, isMain: true),
              actionCircle(Icons.refresh, () async {
                await cam?.dispose();

                cam = null;

                setState(() {
                  active = false;
                });
              }),
            ],
          ),
          const SizedBox(height: 26),
          MainButton(
            text: scanning ? 'Memindai...' : 'Mulai Analisis',
            onTap: scanning ? () {} : runScan,
          ),
          if (last != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Scan terakhir: ${last!.status} - ${last!.result.tilt}°',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget actionCircle(
    IconData icon,
    VoidCallback onTap, {
    bool isMain = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isMain ? 82 : 62,
        height: isMain ? 82 : 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isMain
              ? const LinearGradient(
                  colors: [Color(0xff2743ff), Color(0xffc8f1ef)],
                )
              : null,
          color: isMain ? null : Colors.white.withValues(alpha: .7),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .10),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: isMain ? 36 : 28,
          color: isMain ? Colors.white : AppColors.blue,
        ),
      ),
    );
  }

  Widget corner() {
    return SizedBox(
      width: 42,
      height: 42,
      child: CustomPaint(painter: CornerPainter()),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        bottomNavigationBar: const AppBottomNav(currentIndex: 1),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatBotPage()),
            );
          },
          backgroundColor: AppColors.blue,
          child: Image.asset(
            'assets/images/Chat Bot (2).png',
            width: 30,
            height: 30,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.smart_toy,
              color: Colors.white,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Terlihat sedikit asimetri postur. Disarankan menjaga kebiasaan postur yang baik.',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lightBlue,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'Mode Data Pengguna',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.softPanel, width: 3),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4),
                    ],
                    color: Colors.white,
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(26),
                        decoration: BoxDecoration(
                          color: AppColors.softPanel,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Form(
                          key: formKey,
                          autovalidateMode: AutovalidateMode.disabled,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.person_add_alt_1),
                                  SizedBox(width: 14),
                                  Text(
                                    'Data Pengguna',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              field('Nama Lengkap', 'Masukkan nama lengkap',
                                  nama),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Gender',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  RadioGroup<String>(
                                    groupValue: selectedGender,
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() {
                                          selectedGender = v;
                                        });
                                      }
                                    },
                                    child: Row(
                                      children: const [
                                        Expanded(
                                          child: RadioListTile<String>(
                                            value: 'Pria',
                                            title: Text('Pria'),
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                        Expanded(
                                          child: RadioListTile<String>(
                                            value: 'Wanita',
                                            title: Text('Wanita'),
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                ],
                              ),
                              field(
                                'Umur',
                                'Masukkan Umur',
                                umur,
                                type: TextInputType.number,
                              ),
                              field(
                                'Tinggi Badan',
                                'Masukkan tinggi badan (cm)',
                                tinggi,
                                type: TextInputType.number,
                              ),
                              field(
                                'Berat Badan',
                                'Masukkan berat badan (kg)',
                                berat,
                                type: TextInputType.number,
                              ),
                              const SizedBox(height: 10),
                              MainButton(
                                text: 'Lanjut ke Scanner',
                                onTap: () {
                                  if (formKey.currentState!.validate()) {
                                    scrollController.animateTo(
                                      720,
                                      duration:
                                          const Duration(milliseconds: 600),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      scanner(),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_nativeAdIsLoaded && _nativeAd != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 90,
                        child: AdWidget(ad: _nativeAd!),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

class CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, 0)
      ..lineTo(0, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class BodyOutlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(centerX, 55), width: 60, height: 75),
      paint,
    );
    canvas.drawLine(
      Offset(centerX, 95),
      Offset(centerX, size.height - 35),
      paint,
    );
    canvas.drawLine(
      Offset(centerX - 90, 130),
      Offset(centerX + 90, 130),
      paint,
    );
    canvas.drawLine(
      Offset(centerX - 70, 225),
      Offset(centerX + 70, 225),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, size.height / 2),
          width: 170,
          height: 260,
        ),
        const Radius.circular(80),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ChatMessage {
  final String text;
  final bool fromUser;
  const ChatMessage(this.text, this.fromUser);
}

class ChatBotPage extends StatefulWidget {
  const ChatBotPage({super.key});

  @override
  State<ChatBotPage> createState() => _ChatBotPageState();
}

class _ChatBotPageState extends State<ChatBotPage> {
  final ctrl = TextEditingController();
  final list = ScrollController();
  final messages = <ChatMessage>[
    const ChatMessage(
      'Halo! Saya Scolix Assistant.\nSaya dapat membantu informasi edukasi postur tubuh dan penggunaan aplikasi',
      false,
    ),
  ];

  bool aiLoading = false;

  final qs = const [
    'Tips menjaga postur tubuh',
    'Cara menggunakan scanner',
    'Cara membaca hasil postur',
    'Kebiasaan postur yang baik',
    'Latihan peregangan sederhana',
    'Cara memahami hasil postur',
  ];

  @override
  void dispose() {
    ctrl.dispose();
    list.dispose();
    super.dispose();
  }

  Future<void> send(String t) async {
    final v = t.trim();
    if (v.isEmpty || aiLoading) return;

    ctrl.clear();

    setState(() {
      messages.add(ChatMessage(v, true));
      aiLoading = true;
    });

    final reply = await AiChatService.ask(v);

    if (!mounted) return;

    setState(() {
      messages.add(ChatMessage(reply, false));
      aiLoading = false;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      if (list.hasClients) {
        list.animateTo(
          list.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget bubble(ChatMessage m) => Align(
        alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(
            left: m.fromUser ? 110 : 20,
            right: m.fromUser ? 12 : 88,
            top: 12,
          ),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: m.fromUser ? const Color(0xffaebcff) : Colors.white,
            border:
                m.fromUser ? null : Border.all(color: const Color(0xff7187ff)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(m.text),
        ),
      );

  Widget qtile(String q) => GestureDetector(
        onTap: () => send(q),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xff9bb5ff)),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 11,
                backgroundColor: Color(0xff8ea8ff),
                child: Text(
                  '?',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(q)),
              const Icon(Icons.arrow_forward_ios, color: Color(0xff4f93ff)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xfff8f8ff),
        bottomNavigationBar: const AppBottomNav(currentIndex: 0),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                height: 68,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 3,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    Image.asset(
                      'assets/images/ChatGPT Image Apr 29, 2026, 09_47_11 PM.png',
                      width: 46,
                      height: 46,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Scolix Assistant',
                      style: TextStyle(
                        color: AppColors.blue,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 46,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xffb6c3ff),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.notifications,
                          color: AppColors.blue),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: list,
                  padding: const EdgeInsets.only(top: 12, bottom: 16),
                  children: [
                    ...messages.map(bubble),
                    if (aiLoading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text('AI sedang menganalisis...'),
                          ],
                        ),
                      ),
                    const SizedBox(height: 34),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xffa8c4ff)),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 3,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(children: qs.map(qtile).toList()),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.black)),
                ),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xffa9c1ff),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 22),
                      Expanded(
                        child: TextField(
                          controller: ctrl,
                          decoration: const InputDecoration(
                            hintText: 'Tulis Pesan...',
                            border: InputBorder.none,
                          ),
                          onSubmitted: send,
                        ),
                      ),
                      IconButton(
                        onPressed: () => send(ctrl.text),
                        icon: const Icon(Icons.send_outlined, size: 30),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-3940256099942544/2934735716';

  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;
  final String _interstitialAdUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/1033173712'
      : 'ca-app-pub-3940256099942544/4411468910';

  @override
  void initState() {
    super.initState();
    _loadInterstitialAd();
  }

  void _loadInterstitialAd() {
    if (_isInterstitialLoading) return;
    _isInterstitialLoading = true;
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('History Interstitial Ad loaded.');
          _interstitialAd = ad;
          _isInterstitialLoading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('History Interstitial Ad failed to load: $error');
          _interstitialAd = null;
          _isInterstitialLoading = false;
        },
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isAdLoaded) {
      _loadAd();
    }
  }

  void _loadAd() async {
    final size = await AdSize.getAnchoredAdaptiveBannerAdSize(
      Orientation.portrait,
      MediaQuery.sizeOf(context).width.truncate(),
    );

    if (size == null) return;

    BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint("Ad was loaded.");
          if (mounted) {
            setState(() {
              _bannerAd = ad as BannerAd;
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint("Ad failed to load with error: $err");
          ad.dispose();
        },
        onAdOpened: (Ad ad) => debugPrint("Ad was opened."),
        onAdClosed: (Ad ad) => debugPrint("Ad was closed."),
        onAdImpression: (Ad ad) => debugPrint("Ad recorded an impression."),
        onAdClicked: (Ad ad) => debugPrint("Ad was clicked."),
        onAdWillDismissScreen: (Ad ad) => debugPrint("Ad will be dismissed."),
      ),
    ).load();
  }

  final search = TextEditingController();

  String query = '';

  @override
  void dispose() {
    _interstitialAd?.dispose();
    _bannerAd?.dispose();
    search.dispose();
    super.dispose();
  }

  Widget timelineDot(int index) {
    return Column(
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: index == 0 ? AppColors.blue : Colors.grey,
        ),
        Container(
          width: 2,
          height: 80,
          color: Colors.grey.shade300,
        ),
      ],
    );
  }

  Widget item(Map<String, dynamic> data) {
    final score = ((data['score'] ?? 0) as num).toDouble();

    final createdAt = data['createdAt'] as Timestamp?;
    final date = createdAt?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading:
            data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      data['imageUrl'],
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          return child;
                        }

                        return const SizedBox(
                          width: 60,
                          height: 60,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) {
                        return CircleAvatar(
                          backgroundColor: score >= 85
                              ? Colors.green
                              : score >= 70
                                  ? Colors.orange
                                  : Colors.red,
                          child: const Icon(
                            Icons.analytics,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  )
                : CircleAvatar(
                    backgroundColor: score >= 85
                        ? Colors.green
                        : score >= 70
                            ? Colors.orange
                            : Colors.red,
                    child: const Icon(
                      Icons.analytics,
                      color: Colors.white,
                    ),
                  ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                data['pemeriksaan'] ?? '-',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: score >= 85
                    ? Colors.green.shade100
                    : score >= 70
                        ? Colors.orange.shade100
                        : Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                score >= 85
                    ? "Baik"
                    : score >= 70
                        ? "Sedang"
                        : "Perlu Perhatian",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: score >= 85
                      ? Colors.green
                      : score >= 70
                          ? Colors.orange
                          : Colors.red,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            if (date != null)
              Text(
                "${date.day}/${date.month}/${date.year} "
                "${date.hour.toString().padLeft(2, '0')}:"
                "${date.minute.toString().padLeft(2, '0')}",
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              "Skor : ${score.toStringAsFixed(0)}/100",
            ),
            Text(
              "Bahu : ${((data['shoulderDiff'] ?? 0) as num).toStringAsFixed(1)}°",
            ),
            Text(
              "Pinggul : ${((data['hipDiff'] ?? 0) as num).toStringAsFixed(1)}°",
            ),
          ],
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
        ),
        onTap: () {
          _showInterstitialAndNavigate(data);
        },
      ),
    );
  }

  void _showInterstitialAndNavigate(Map<String, dynamic> data) {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _interstitialAd = null;
          _loadInterstitialAd(); // Load next ad
          _navigateToDetail(data);
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          _interstitialAd = null;
          _loadInterstitialAd(); // Load next ad
          _navigateToDetail(data);
        },
      );
      _interstitialAd!.show();
    } else {
      _navigateToDetail(data);
      _loadInterstitialAd(); // Load again
    }
  }

  void _navigateToDetail(Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanDetailPage(
          data: data,
        ),
      ),
    );
  }

  Widget angleChart(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          "Belum ada data grafik",
        ),
      );
    }

    final values = docs.take(5).toList().reversed.map((e) {
      final data = e.data() as Map<String, dynamic>;

      return ((data['score'] ?? 0) as num).toDouble();
    }).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: 100,
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(show: true),
            titlesData: const FlTitlesData(show: false),
            lineBarsData: [
              LineChartBarData(
                isCurved: true,
                spots: List.generate(
                  values.length,
                  (index) => FlSpot(
                    index.toDouble(),
                    values[index],
                  ),
                ),
                barWidth: 3,
                dotData: const FlDotData(
                  show: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> buildStats(
    List<QueryDocumentSnapshot> docs,
  ) {
    if (docs.isEmpty) {
      return {
        'total': 0,
        'average': 0.0,
        'best': 0.0,
      };
    }

    double totalScore = 0;
    double bestScore = 0;

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;

      final score = ((data['score'] ?? 0) as num).toDouble();

      totalScore += score;

      if (score > bestScore) {
        bestScore = score;
      }
    }

    return {
      'total': docs.length,
      'average': totalScore / docs.length,
      'best': bestScore,
    };
  }

  Map<String, dynamic> buildTrend(
    List<QueryDocumentSnapshot> docs,
  ) {
    if (docs.length < 2) {
      return {
        'change': 0.0,
        'improving': true,
      };
    }

    final trendDocs = docs.length > 5 ? docs.take(5).toList() : docs;

    final newest =
        (((trendDocs.first.data() as Map<String, dynamic>)['score'] ?? 0)
                as num)
            .toDouble();

    final oldest =
        (((trendDocs.last.data() as Map<String, dynamic>)['score'] ?? 0) as num)
            .toDouble();

    final change = newest - oldest;

    return {
      'change': change,
      'improving': change >= 0,
      'latest': newest,
      'oldest': oldest,
    };
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xfff8f8ff),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_bannerAd != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: SizedBox(
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),
            ),
          const AppBottomNav(currentIndex: 2),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatBotPage()),
          );
        },
        backgroundColor: AppColors.blue,
        child: Image.asset(
          'assets/images/Chat Bot (2).png',
          width: 30,
          height: 30,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.smart_toy,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('scan_history')
              .where('uid', isEqualTo: uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(
                        'Gagal memuat riwayat:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            // Sort client-side berdasarkan createdAt descending
            final rawDocs = snapshot.data?.docs ?? [];
            rawDocs.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTime = (aData['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              final bTime = (bData['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              return bTime.compareTo(aTime);
            });


            final q = query.toLowerCase();

            final data = q.isEmpty
                ? rawDocs
                : rawDocs.where((doc) {
                    final x = doc.data() as Map<String, dynamic>;

                    return (x['pemeriksaan'] ?? '')
                        .toString()
                        .toLowerCase()
                        .contains(q);
                  }).toList();

            final stats = buildStats(data);
            final trend = buildTrend(data);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xffc3d4ff),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Riwayat Analisis",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 12),

                        TextField(
                          controller: search,
                          onChanged: (value) {
                            setState(() {
                              query = value;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: "Cari hasil pemeriksaan",
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Dashboard Statistik
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  const Text(
                                    "Total",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${stats['total']}",
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  const Text(
                                    "Rata-rata",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    (stats['average'] as double)
                                        .toStringAsFixed(0),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  const Text(
                                    "Terbaik",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    (stats['best'] as double)
                                        .toStringAsFixed(0),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: trend['improving']
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                trend['improving']
                                    ? Icons.trending_up
                                    : Icons.trending_down,
                                color: trend['improving']
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  trend['improving']
                                      ? "Skor postur meningkat ${trend['change'].toStringAsFixed(1)} poin"
                                      : "Skor postur menurun ${trend['change'].abs().toStringAsFixed(1)} poin",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        angleChart(data),

                        const SizedBox(height: 20),

                        const Text(
                          "Timeline Scan",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 10),

                        if (data.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 20,
                            ),
                            child: Center(
                              child: Text(
                                "Belum ada riwayat scan",
                              ),
                            ),
                          )
                        else
                          ...data.asMap().entries.map(
                                (e) => Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    timelineDot(
                                      e.key,
                                    ),
                                    Expanded(
                                      child: item(
                                        e.value.data() as Map<String, dynamic>,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class LoginChoicePage extends StatelessWidget {
  const LoginChoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: bgGradient(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const Spacer(),
                Image.asset('assets/images/Icon.png', width: 120),
                const SizedBox(height: 24),
                const Text(
                  'Masuk Sebagai',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 36),
                MainButton(
                  text: 'Login User',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                ),
                const SizedBox(height: 18),
                MainButton(
                  text: 'Login Admin',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminLoginPage()),
                    );
                  },
                ),
                const SizedBox(height: 50),
                footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();

  final passwordController = TextEditingController();

  bool loading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> loginAdmin() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .get();

      final role = doc.data()?['role'];

      if (role != 'admin') {
        await FirebaseAuth.instance.signOut();

        throw Exception('Akun ini bukan admin');
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Login admin gagal')));
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: bgGradient(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 60),
                const Text(
                  'Login Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xfff8f8ff),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Form(
                    key: formKey,
                    autovalidateMode: AutovalidateMode.disabled,
                    child: Column(
                      children: [
                        CustomInput(
                          label: 'Email Admin',
                          hint: 'Masukkan email admin',
                          controller: emailController,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Email wajib diisi';
                            }

                            return null;
                          },
                        ),
                        CustomInput(
                          label: 'Password Admin',
                          hint: 'Masukkan password admin',
                          password: true,
                          controller: passwordController,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Password wajib diisi';
                            }

                            return null;
                          },
                        ),
                        MainButton(
                          text: 'Masuk Admin',
                          onTap: loginAdmin,
                          loading: loading,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    '← Kembali',
                    style: TextStyle(
                      color: AppColors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  String active = 'dashboard';

  final menus = const [
    ['dashboard', 'Dashboard', Icons.home],
    ['profile', 'Pengguna', Icons.person],
    ['scans', 'Hasil Scan', Icons.camera_alt],
    ['education', 'Edukasi', Icons.article],
    ['chatbot', 'Chatbot', Icons.smart_toy],
    ['settings', 'Pengaturan', Icons.settings],
  ];

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (r) => false,
    );
  }

  Stream<int> countStream(String collection) {
    return FirebaseFirestore.instance
        .collection(collection)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Stream<int> riskStream() {
    return FirebaseFirestore.instance
        .collection('scan_results')
        .where('status', whereIn: ['Sedang/Berat', 'Sedang', 'Berat'])
        .snapshots()
        .map((s) => s.docs.length);
  }

  Color statusColor(String status) {
    if (status == 'Normal') return Colors.green;
    if (status == 'Ringan') return AppColors.blue;
    if (status == 'Sedang' || status == 'Sedang/Berat') return Colors.orange;
    return Colors.red;
  }

  Widget statCard(
    String title,
    Stream<int> stream,
    IconData icon,
    String note,
  ) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snapshot) {
        final value = snapshot.data ?? 0;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: AppColors.blue, size: 26),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      note,
                      style: const TextStyle(
                        color: AppColors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 22,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget menuButton(String id, String label, IconData icon) {
    final selected = active == id;

    return InkWell(
      onTap: () => setState(() => active = id),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xff2545ff), Color(0xffbffaff)],
                )
              : null,
          color: selected ? null : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? Colors.white : Colors.black54),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget header(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xff1d4ed8), Color(0xff4f7cff), Color(0xffd6f7f4)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Guided Capture + QC',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Panel admin untuk monitoring pasien, hasil scan, edukasi, dan chatbot Scolix-AI.',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget dashboardPage() {
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8,
          children: [
            statCard(
              'Total Pengguna',
              FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'user')
                  .snapshots()
                  .map((s) => s.docs.length),
              Icons.people,
              'Realtime',
            ),
            statCard(
              'Total Scan',
              countStream('scan_results'),
              Icons.camera_alt,
              'Realtime',
            ),
            statCard(
              'Risiko Sedang',
              riskStream(),
              Icons.monitor_heart,
              'Perlu review',
            ),
            statCard(
              'Artikel Aktif',
              Stream.value(3),
              Icons.article,
              '3 kategori',
            ),
          ],
        ),
        const SizedBox(height: 20),
        latestScanCard(),
      ],
    );
  }

  Widget latestScanCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review Terbaru',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Hasil scan yang masuk dari user',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 14),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('scan_results')
                .orderBy('createdAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return const Text('Belum ada data scan.');
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data();
                  final profile =
                      data['profile'] as Map<String, dynamic>? ?? {};
                  final result = data['result'] as Map<String, dynamic>? ?? {};
                  final status = data['status']?.toString() ?? '-';

                  final rawTilt = result['tilt'];
                  final String tiltStr;
                  if (rawTilt is num) {
                    tiltStr = rawTilt.toStringAsFixed(1);
                  } else {
                    tiltStr = double.tryParse(rawTilt?.toString() ?? '')?.toStringAsFixed(1) ?? '0.0';
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.lightBlue,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.camera_alt, color: AppColors.blue, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                profile['name'] ?? 'Tanpa nama',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'Tilt: $tiltStr°',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor(status).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: statusColor(status),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget profilePage() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Data Pengguna',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            ...docs.map((doc) {
              final d = doc.data();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 6),
                  ],
                ),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(
                    d['name']?.toString().isEmpty == false ? d['name'] : 'User',
                  ),
                  subtitle: Text(d['email'] ?? '-'),
                  trailing: Text(
                    d['role'] ?? 'user',
                    style: const TextStyle(
                      color: AppColors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget scansPage() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('scan_results')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hasil Scan',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            ...docs.map((doc) {
              final data = doc.data();
              final profile = data['profile'] as Map<String, dynamic>? ?? {};
              final result = data['result'] as Map<String, dynamic>? ?? {};
              final status = data['status']?.toString() ?? '-';

              final rawTilt = result['tilt'];
              final String tiltStr;
              if (rawTilt is num) {
                tiltStr = rawTilt.toStringAsFixed(1);
              } else {
                tiltStr = double.tryParse(rawTilt?.toString() ?? '')?.toStringAsFixed(1) ?? '0.0';
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 6),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.lightBlue,
                          child: Icon(Icons.camera_alt, color: AppColors.blue, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile['name'] ?? 'Tanpa nama',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tilt: $tiltStr°',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor(status).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: statusColor(status),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (data['recommendation'] != null &&
                        data['recommendation'].toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Text(
                        'Rekomendasi: ${data['recommendation']}',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget educationPage() {
    const data = [
      ['Panduan Postur Tubuh', 'Artikel', Icons.article],
      ['4 Gejala Skoliosis', 'Infografis', Icons.image],
      ['Fun Facts Seputar Skoliosis', 'Funfact', Icons.lightbulb],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Konten Edukasi',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        ...data.map((e) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 6),
              ],
            ),
            child: Row(
              children: [
                Icon(e[2] as IconData, color: AppColors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${e[0]}\n${e[1]}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Icon(Icons.edit, color: AppColors.blue),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget chatbotPage() {
    const faqs = [
      ['Apa itu skoliosis?', 'Kondisi tulang belakang melengkung ke samping.'],
      [
        'Mengapa skoliosis terjadi?',
        'Bisa dipengaruhi faktor genetik, postur, atau idiopatik.',
      ],
      [
        'Gejala yang harus diwaspadai?',
        'Bahu tidak sejajar, pinggul miring, nyeri punggung.',
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FAQ Chatbot',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        ...faqs.map((e) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 6),
              ],
            ),
            child: ListTile(
              leading: const Icon(Icons.question_answer, color: AppColors.blue),
              title: Text(
                e[0],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(e[1]),
              trailing: const Icon(Icons.edit, color: AppColors.blue),
            ),
          );
        }),
      ],
    );
  }

  Widget settingsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pengaturan Sistem',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        settingCard(
          Icons.security,
          'Privasi Data',
          'Consent pasien dan keamanan data.',
        ),
        settingCard(
          Icons.smart_toy,
          'Konfigurasi AI',
          'Endpoint backend chatbot dan analisis.',
        ),
        settingCard(
          Icons.download,
          'Export Report',
          'Format PDF dan JSON untuk riwayat.',
        ),
      ],
    );
  }

  Widget settingCard(IconData icon, String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$title\n$desc',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget pageContent() {
    if (active == 'profile') return profilePage();
    if (active == 'scans') return scansPage();
    if (active == 'education') return educationPage();
    if (active == 'chatbot') return chatbotPage();
    if (active == 'settings') return settingsPage();
    return dashboardPage();
  }

  String get activeTitle {
    return menus.firstWhere((m) => m[0] == active)[1] as String;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff8fbff),
      body: SafeArea(
        child: Row(
          children: [
            Container(
              width: 72,
              padding: const EdgeInsets.symmetric(vertical: 16),
              color: Colors.white,
              child: Column(
                children: [
                  Image.asset('assets/images/Icon.png', width: 42),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: menus.map(
                          (m) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: IconButton(
                              tooltip: m[1] as String,
                              onPressed: () => setState(() => active = m[0] as String),
                              icon: Icon(
                                m[2] as IconData,
                                color: active == m[0] ? AppColors.blue : Colors.black45,
                                size: 24,
                              ),
                            ),
                          ),
                        ).toList(),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: logout,
                    icon: const Icon(Icons.logout, color: Colors.red, size: 24),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    header(activeTitle),
                    const SizedBox(height: 20),
                    pageContent(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AngleChartPainter extends CustomPainter {
  final List<double> values;

  AngleChartPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1;

    final linePaint = Paint()
      ..color = AppColors.blue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      axisPaint,
    );
    canvas.drawLine(const Offset(0, 0), Offset(0, size.height), axisPaint);

    if (values.length < 2) {
      final y = size.height - (values.first / 10).clamp(0, 1) * size.height;
      canvas.drawCircle(
        Offset(size.width / 2, y),
        5,
        Paint()..color = AppColors.blue,
      );
      return;
    }

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = (size.width / (values.length - 1)) * i;
      final y = size.height - (values[i] / 10).clamp(0, 1) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = AppColors.blue);
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant AngleChartPainter oldDelegate) =>
      oldDelegate.values != values;
}
