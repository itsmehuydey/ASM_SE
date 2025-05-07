// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_application_1/data/models/booking/booking_request.dart';
// import 'package:dartz/dartz.dart';
// import 'package:flutter_application_1/data/sources/room/room_firebase_service.dart';
// import 'package:flutter_application_1/service_locator.dart';

// abstract class BookingFirebaseService {
//   Future<Either<String, String>> createBooking(BookingRequest bookingRequest);
//   Future<Either<String, bool>> checkRoomAvailability(String buildingCode, String roomNumber, DateTime date, TimeOfDay startTime, int duration, int numberOfPeople);
//   Stream<List<BookingRequest>> streamUserBookings(String userId);
//   Stream<List<BookingRequest>> streamRoomBookings(String buildingCode, String roomNumber);
//   Future<List<BookingRequest>> getBookings();
//   Future<void> updateBooking(BookingRequest booking);
//   Future<void> deleteBooking(BookingRequest booking);
// }

// class BookingFirebaseServiceImpl implements BookingFirebaseService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;

//   @override
//   Future<Either<String, String>> createBooking(BookingRequest bookingRequest) async {
//     try {
//       final currentUser = _auth.currentUser;
//       if (currentUser == null) {
//         return Left('Bạn chưa đăng nhập');
//       }

//       final availabilityCheck = await checkRoomAvailability(
//         bookingRequest.buildingCode,
//         bookingRequest.roomNumber,
//         bookingRequest.bookingDate,
//         bookingRequest.startTime,
//         bookingRequest.duration,
//         bookingRequest.numberOfPeople,
//       );

//       if (availabilityCheck.isLeft()) {
//         return availabilityCheck.fold(
//           (error) => Left(error),
//           (r) => Left('Lỗi không xác định'),
//         );
//       }

//       // Tạo BookingRequest với userName và userEmail
//       final updatedRequest = BookingRequest(
//         userId: currentUser.uid,
//         userName: currentUser.displayName, // Lấy tên từ FirebaseAuth
//         userEmail: currentUser.email ?? 'Không có email', // Lấy email từ FirebaseAuth
//         buildingCode: bookingRequest.buildingCode,
//         roomNumber: bookingRequest.roomNumber,
//         floor: bookingRequest.floor,
//         bookingDate: bookingRequest.bookingDate,
//         startTime: bookingRequest.startTime,
//         duration: bookingRequest.duration,
//         numberOfPeople: bookingRequest.numberOfPeople,
//         status: bookingRequest.status ?? 'pending',
//         createdAt: DateTime.now(),
//       );

//       final docId = '${updatedRequest.userId}_${updatedRequest.roomNumber}_${updatedRequest.bookingDate.toIso8601String()}';
//       await _firestore.collection('bookings').doc(docId).set(updatedRequest.toJson());

//       final roomService = sl<RoomFirebaseService>();
//       final updateResult = await roomService.updateRoomStatus(
//         bookingRequest.buildingCode,
//         bookingRequest.roomNumber,
//         'not_available',
//       );

//       if (updateResult.isLeft()) {
//         print('Có lỗi khi cập nhật trạng thái phòng: ${updateResult.fold((l) => l, (r) => '')}');
//       } else {
//         print('Đã cập nhật trạng thái phòng thành công');
//       }

//       return Right(docId);
//     } catch (e) {
//       print('Lỗi đặt phòng: ${e.toString()}');
//       return Left('Đã xảy ra lỗi: ${e.toString()}');
//     }
//   }

//   @override
//   Future<Either<String, bool>> checkRoomAvailability(
//       String buildingCode, String roomNumber, DateTime date, TimeOfDay startTime, int duration, int numberOfPeople) async {
//     try {
//       final roomDocId = '${buildingCode}_${roomNumber.replaceAll('.', '_')}';
//       final roomDoc = await _firestore.collection('rooms').doc(roomDocId).get();

//       if (!roomDoc.exists) {
//         return Left('Phòng không tồn tại');
//       }

//       final roomData = roomDoc.data()!;
//       if (roomData['status'] != 'available') {
//         return Left('Phòng đã được đặt hoặc đang bảo trì');
//       }

//       if (roomData['capacity'] < numberOfPeople) {
//         return Left('Sức chứa phòng không đủ cho $numberOfPeople người');
//       }

//       final startDateTime = DateTime(
//         date.year,
//         date.month,
//         date.day,
//         startTime.hour,
//         startTime.minute,
//       );
//       final endDateTime = startDateTime.add(Duration(hours: duration));

//       final snapshot = await _firestore
//           .collection('bookings')
//           .where('buildingCode', isEqualTo: buildingCode)
//           .where('roomNumber', isEqualTo: roomNumber)
//           .where('bookingDate', isEqualTo: date.toIso8601String())
//           .get();

//       for (var doc in snapshot.docs) {
//         final booking = BookingRequest.fromJson(doc.data());
//         final bookingStart = DateTime(
//           booking.bookingDate.year,
//           booking.bookingDate.month,
//           booking.bookingDate.day,
//           booking.startTime.hour,
//           booking.startTime.minute,
//         );
//         final bookingEnd = bookingStart.add(Duration(hours: booking.duration));

//         if ((startDateTime.isBefore(bookingEnd) && startDateTime.isAfter(bookingStart)) ||
//             (endDateTime.isBefore(bookingEnd) && endDateTime.isAfter(bookingStart)) ||
//             (startDateTime.isAtSameMomentAs(bookingStart) || endDateTime.isAtSameMomentAs(bookingEnd))) {
//           return const Right(false);
//         }
//       }

//       return const Right(true);
//     } catch (e) {
//       print('Lỗi kiểm tra phòng: ${e.toString()}');
//       return Left('Lỗi kiểm tra tình trạng phòng: ${e.toString()}');
//     }
//   }

//   @override
//   Stream<List<BookingRequest>> streamUserBookings(String userId) {
//     return _firestore.collection('bookings')
//         .where('userId', isEqualTo: userId)
//         .snapshots()
//         .map((snapshot) =>
//             snapshot.docs.map((doc) => BookingRequest.fromJson(doc.data())).toList());
//   }

//   @override
//   Stream<List<BookingRequest>> streamRoomBookings(String buildingCode, String roomNumber) {
//     final today = DateTime.now();
//     final dateString = today.toIso8601String().split('T')[0];

//     return _firestore.collection('bookings')
//         .where('buildingCode', isEqualTo: buildingCode)
//         .where('roomNumber', isEqualTo: roomNumber)
//         .where('bookingDate', isGreaterThanOrEqualTo: dateString)
//         .orderBy('bookingDate')
//         .orderBy('startTime.hour')
//         .orderBy('startTime.minute')
//         .snapshots()
//         .map((snapshot) =>
//             snapshot.docs.map((doc) => BookingRequest.fromJson(doc.data())).toList());
//   }

//   @override
//   Future<List<BookingRequest>> getBookings() async {
//     final snapshot = await _firestore.collection('bookings').get();
//     return snapshot.docs
//         .map((doc) => BookingRequest.fromJson(doc.data()))
//         .toList();
//   }

//   @override
//   Future<void> updateBooking(BookingRequest booking) async {
//     final docId = '${booking.userId}_${booking.roomNumber}_${booking.bookingDate.toIso8601String()}';
//     print('Updating booking with docId: $docId');
//     print('Booking data: ${booking.toJson()}');
//     await _firestore.collection('bookings').doc(docId).set(
//           booking.toJson(),
//           SetOptions(merge: true),
//         );
//   }

//   @override
//   Future<void> deleteBooking(BookingRequest booking) async {
//     final docId = '${booking.userId}_${booking.roomNumber}_${booking.bookingDate.toIso8601String()}';
//     await _firestore.collection('bookings').doc(docId).delete();

//     final roomService = sl<RoomFirebaseService>();
//     await roomService.updateRoomStatus(
//       booking.buildingCode,
//       booking.roomNumber,
//       'available',
//     );
//   }
// }

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/data/models/booking/booking_request.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_application_1/data/sources/room/room_firebase_service.dart';
import 'package:flutter_application_1/service_locator.dart';

abstract class BookingFirebaseService {
  Future<Either<String, String>> createBooking(BookingRequest bookingRequest);
  Future<Either<String, bool>> checkRoomAvailability(
      String buildingCode, String roomNumber, DateTime date, TimeOfDay startTime, int duration, int numberOfPeople);
  Stream<List<BookingRequest>> streamUserBookings(String userId);
  Stream<List<BookingRequest>> streamRoomBookings(String buildingCode, String roomNumber);
  Future<List<BookingRequest>> getBookings();
  Future<void> updateBooking(BookingRequest booking);
  Future<void> deleteBooking(BookingRequest booking);
}

class BookingFirebaseServiceImpl implements BookingFirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Future<Either<String, String>> createBooking(BookingRequest bookingRequest) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return Left('Bạn chưa đăng nhập');
      }

      final availabilityCheck = await checkRoomAvailability(
        bookingRequest.buildingCode,
        bookingRequest.roomNumber,
        bookingRequest.bookingDate,
        bookingRequest.startTime,
        bookingRequest.duration,
        bookingRequest.numberOfPeople,
      );

      if (availabilityCheck.isLeft()) {
        return availabilityCheck.fold(
          (error) => Left(error),
          (r) => Left('Lỗi không xác định'),
        );
      }

      final updatedRequest = BookingRequest(
        userId: currentUser.uid,
        userName: currentUser.displayName,
        userEmail: currentUser.email ?? 'Không có email',
        buildingCode: bookingRequest.buildingCode,
        roomNumber: bookingRequest.roomNumber,
        floor: bookingRequest.floor,
        bookingDate: bookingRequest.bookingDate,
        startTime: bookingRequest.startTime,
        duration: bookingRequest.duration,
        numberOfPeople: bookingRequest.numberOfPeople,
        status: bookingRequest.status ?? 'pending',
        createdAt: DateTime.now(),
      );

      final docId =
          '${updatedRequest.userId}_${updatedRequest.roomNumber}_${updatedRequest.bookingDate.toIso8601String()}';
      await _firestore.collection('bookings').doc(docId).set(updatedRequest.toJson());

      final roomService = sl<RoomFirebaseService>();
      final updateResult = await roomService.updateRoomStatus(
        bookingRequest.buildingCode,
        bookingRequest.roomNumber,
        'not_available',
      );

      if (updateResult.isLeft()) {
        print('Có lỗi khi cập nhật trạng thái phòng: ${updateResult.fold((l) => l, (r) => '')}');
      } else {
        print('Đã cập nhật trạng thái phòng thành công');
      }

      return Right(docId);
    } catch (e) {
      print('Lỗi đặt phòng: ${e.toString()}');
      return Left('Đã xảy ra lỗi: ${e.toString()}');
    }
  }

  @override
  Future<Either<String, bool>> checkRoomAvailability(String buildingCode, String roomNumber, DateTime date,
      TimeOfDay startTime, int duration, int numberOfPeople) async {
    try {
      final roomDocId = '${buildingCode}_${roomNumber.replaceAll('.', '_')}';
      final roomDoc = await _firestore.collection('rooms').doc(roomDocId).get();

      if (!roomDoc.exists) {
        return Left('Phòng không tồn tại');
      }

      final roomData = roomDoc.data()!;
      if (roomData['status'] != 'available') {
        return Left('Phòng đã được đặt hoặc đang bảo trì');
      }

      if (roomData['capacity'] < numberOfPeople) {
        return Left('Sức chứa phòng không đủ cho $numberOfPeople người');
      }

      final startDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        startTime.hour,
        startTime.minute,
      );
      final endDateTime = startDateTime.add(Duration(hours: duration));

      final snapshot = await _firestore
          .collection('bookings')
          .where('buildingCode', isEqualTo: buildingCode)
          .where('roomNumber', isEqualTo: roomNumber)
          .where('bookingDate', isEqualTo: date.toIso8601String())
          .get();

      for (var doc in snapshot.docs) {
        final booking = BookingRequest.fromJson(doc.data());
        final bookingStart = DateTime(
          booking.bookingDate.year,
          booking.bookingDate.month,
          booking.bookingDate.day,
          booking.startTime.hour,
          booking.startTime.minute,
        );
        final bookingEnd = bookingStart.add(Duration(hours: booking.duration));

        if ((startDateTime.isBefore(bookingEnd) && startDateTime.isAfter(bookingStart)) ||
            (endDateTime.isBefore(bookingEnd) && endDateTime.isAfter(bookingStart)) ||
            (startDateTime.isAtSameMomentAs(bookingStart) || endDateTime.isAtSameMomentAs(bookingEnd))) {
          return const Right(false);
        }
      }

      return const Right(true);
    } catch (e) {
      print('Lỗi kiểm tra phòng: ${e.toString()}');
      return Left('Lỗi kiểm tra tình trạng phòng: ${e.toString()}');
    }
  }

  @override
  Stream<List<BookingRequest>> streamUserBookings(String userId) {
    return _firestore
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => BookingRequest.fromJson(doc.data())).toList());
  }

  @override
  Stream<List<BookingRequest>> streamRoomBookings(String buildingCode, String roomNumber) {
    final today = DateTime.now();
    final dateString = today.toIso8601String().split('T')[0];

    return _firestore
        .collection('bookings')
        .where('buildingCode', isEqualTo: buildingCode)
        .where('roomNumber', isEqualTo: roomNumber)
        .where('bookingDate', isGreaterThanOrEqualTo: dateString)
        .orderBy('bookingDate')
        .orderBy('startTime.hour')
        .orderBy('startTime.minute')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => BookingRequest.fromJson(doc.data())).toList());
  }

  @override
  Future<List<BookingRequest>> getBookings() async {
    final snapshot = await _firestore.collection('bookings').get();
    return snapshot.docs.map((doc) => BookingRequest.fromJson(doc.data())).toList();
  }

  @override
  Future<void> updateBooking(BookingRequest booking) async {
    final docId = '${booking.userId}_${booking.roomNumber}_${booking.bookingDate.toIso8601String()}';
    print('Updating booking with docId: $docId');
    print('Booking data: ${booking.toJson()}');
    await _firestore.collection('bookings').doc(docId).set(
          booking.toJson(),
          SetOptions(merge: true),
        );
  }

  @override
  Future<void> deleteBooking(BookingRequest booking) async {
    final docId = '${booking.userId}_${booking.roomNumber}_${booking.bookingDate.toIso8601String()}';
    await _firestore.collection('bookings').doc(docId).delete();

    final roomService = sl<RoomFirebaseService>();
    await roomService.updateRoomStatus(
      booking.buildingCode,
      booking.roomNumber,
      'available',
    );
  }
}
