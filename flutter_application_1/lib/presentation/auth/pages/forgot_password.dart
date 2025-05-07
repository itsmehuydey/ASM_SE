import 'package:flutter/material.dart';
import 'package:flutter_application_1/common/widgets/buttons/basic_app_button.dart';
import 'package:flutter_application_1/core/configs/assets/app_images.dart';
import 'package:flutter_application_1/core/configs/theme/app_colors.dart';
import 'package:flutter_application_1/domain/usecases/auth/forgot_password.dart';
import 'package:flutter_application_1/presentation/auth/pages/signin.dart';
import 'package:flutter_application_1/service_locator.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (_emailController.text.trim().isEmpty) {
      _showSnackBar('Vui lòng nhập email của bạn');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    var result = await sl<ForgotPasswordUseCase>().call(_emailController.text.trim());

    setState(() {
      _isLoading = false;
    });

    result.fold(
      (error) => _showSnackBar(error),
      (success) {
        _showSnackBar(success);
        setState(() {
          _emailSent = true;
        });
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Image.asset(
          AppImages.logo_start,
          height: 40,
          width: 40,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Quên mật khẩu',
              style: TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (!_emailSent)
              const Text(
                'Vui lòng nhập email của bạn để nhận liên kết đặt lại mật khẩu',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              )
            else
              const Text(
                'Email đặt lại mật khẩu đã được gửi. Vui lòng kiểm tra hộp thư của bạn và làm theo hướng dẫn.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 40),
            if (!_emailSent) ...[
              _buildEmailField(context),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : BasicAppButton(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      onPressed: _sendResetEmail,
                      title: 'Gửi yêu cầu',
                    ),
            ] else ...[
              BasicAppButton(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => SigninPage()),
                    (route) => false,
                  );
                },
                title: 'Quay lại đăng nhập',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField(BuildContext context) {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(
        hintText: 'Email',
      ).applyDefaults(
        Theme.of(context).inputDecorationTheme,
      ),
    );
  }
} 