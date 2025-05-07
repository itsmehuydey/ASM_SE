import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/data/models/booking/booking_request.dart';
import 'package:flutter_application_1/data/sources/booking/booking_firebase_service.dart';
import 'package:flutter_application_1/domain/repository/booking/booking.dart';
import 'package:flutter_application_1/service_locator.dart';

class BookingRepositoryImpl implements BookingRepository {
  @override
  Future<Either<String, String>> createBooking(BookingRequest bookingRequest) async {
    return await sl<BookingFirebaseService>().createBooking(bookingRequest);
  }

  @override
  Future<Either<String, bool>> checkRoomAvailability(
      String buildingCode, String roomNumber, DateTime date, TimeOfDay startTime, int duration, int numberOfPeople) async {
    return await sl<BookingFirebaseService>().checkRoomAvailability(
        buildingCode, roomNumber, date, startTime, duration, numberOfPeople);
  }

  @override
  Stream<List<BookingRequest>> streamUserBookings(String userId) {
    return sl<BookingFirebaseService>().streamUserBookings(userId);
  }

  @override
  Stream<List<BookingRequest>> streamRoomBookings(String buildingCode, String roomNumber) {
    return sl<BookingFirebaseService>().streamRoomBookings(buildingCode, roomNumber);
  }

  @override
  Future<Either<String, List<BookingRequest>>> getBookings() async {
    try {
      final bookings = await sl<BookingFirebaseService>().getBookings();
      return Right(bookings);
    } catch (e) {
      return Left('Lỗi khi lấy danh sách đặt phòng: $e');
    }
  }

  @override
  Future<Either<String, void>> updateBooking(BookingRequest booking) async {
    try {
      await sl<BookingFirebaseService>().updateBooking(booking);
      return const Right(null);
    } catch (e) {
      return Left('Lỗi khi cập nhật đặt phòng: $e');
    }
  }

  @override
  Future<Either<String, void>> deleteBooking(BookingRequest booking) async {
    try {
      await sl<BookingFirebaseService>().deleteBooking(booking);
      return const Right(null);
    } catch (e) {
      return Left('Lỗi khi xóa đặt phòng: $e');
    }
  }
}