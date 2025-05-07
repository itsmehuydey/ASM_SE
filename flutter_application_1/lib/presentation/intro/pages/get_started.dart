import 'package:flutter/material.dart';
import 'package:flutter_application_1/common/widgets/buttons/basic_app_button.dart';
import 'package:flutter_application_1/core/configs/assets/app_images.dart';
import 'package:flutter_application_1/presentation/choose_mode/pages/choose_mode.dart';

class GetStartedPage extends StatelessWidget {
  const GetStartedPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 100, horizontal: 30),
            decoration: BoxDecoration(
              image: DecorationImage(
                fit: BoxFit.fill,
                image: AssetImage(AppImages.hcmut_start),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(vertical: 190, horizontal: 30),
            child: Align(alignment: Alignment.topCenter, child: Image.asset(AppImages.logo_start)),
          ),
          Positioned(
            bottom: 20, // Điều chỉnh vị trí theo nhu cầu
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                AppImages.base_text, // Thay bằng tên ảnh mới của bạn
                width: MediaQuery.of(context).size.width * 1, // Điều chỉnh kích thước
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
              padding: EdgeInsets.symmetric(vertical: 50, horizontal: 30),
              child: Column(
                children: [
                  Spacer(),
                  Text('SMART STUDY SPACE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20,
                      )),
                  SizedBox(height: 20),
                  Text(
                    'Welcome to the intelligent study space booking and management system at HCMUT! This application helps students easily search for, reserve, and use modern study spaces!',
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: Colors.white,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  BasicAppButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                      );
                    },
                    title: 'Bắt đầu',
                  ),
                ],
              ))
        ],
      ),
    );
  }
}
