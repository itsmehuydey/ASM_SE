import 'package:dartz/dartz.dart';
import 'package:flutter_application_1/data/models/auth/create_user_req.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/data/models/auth/signin_user_req.dart';

abstract class AuthFirebaseService {
  Future<Either> signup(CreateUserReq createUserReq);
  Future<Either> signin(SigninUserReq signinUserReq);
  Future<Either> forgotPassword(String email);
}

class AuthFirebaseServiceImpl extends AuthFirebaseService {
  @override
  Future<Either> signup(CreateUserReq createUserReq) async {
    // Implement Firebase signup logic here
    try {
      await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: createUserReq.email, password: createUserReq.password);
      return Right('Đăng ký thành công'); // Return success or user data
      // If successful, return user data or token
    } on FirebaseAuthException catch (e) {
      // Handle Firebase signup error
      String message = '';
      if (e.code == 'weak-password') {
        message = 'Mật khẩu quá yếu';
      } else if (e.code == 'email-already-in-use') {
        message = 'Email đã được sử dụng';
      } else if (e.code == 'invalid-email') {
        message = 'Email không hợp lệ';
      }
      return Left(message); // Return error message
    }
  }

  @override
  Future<Either> signin(SigninUserReq signinUserReq) async {
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: signinUserReq.email, password: signinUserReq.password);
      return Right('Đăng nhập thành công'); // Return success or user data
      // If successful, return user data or token
    } on FirebaseAuthException catch (e) {
      // Handle Firebase signup error
      String message = '';
      if (e.code == 'invalid-credential') {
        message = 'Sai mật khẩu';
      } else if (e.code == 'invalid-email') {
        message = 'Email không hợp lệ';
      }
      return Left(message); // Return error message
    }
  }
  
  @override
  Future<Either> forgotPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      return Right('Email đặt lại mật khẩu đã được gửi');
    } on FirebaseAuthException catch (e) {
      String message = '';
      if (e.code == 'invalid-email') {
        message = 'Email không hợp lệ';
      } else if (e.code == 'user-not-found') {
        message = 'Không tìm thấy người dùng với email này';
      } else {
        message = 'Đã xảy ra lỗi: ${e.message}';
      }
      return Left(message);
    }
  }
}
