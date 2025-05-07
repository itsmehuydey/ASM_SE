import 'package:flutter_application_1/core/usecase/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_application_1/service_locator.dart';
import 'package:flutter_application_1/domain/repository/auth/auth.dart';

class ForgotPasswordUseCase implements UseCase<Either, String> {
  @override
  Future<Either> call(String? params) async {
    return sl<AuthRepository>().forgotPassword(params!);
  }
} 