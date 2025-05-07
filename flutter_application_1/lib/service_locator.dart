import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/data/repository/building/building.dart';
import 'package:flutter_application_1/data/repository/room/room.dart';
import 'package:flutter_application_1/data/sources/building/building_firebase_service.dart';
import 'package:flutter_application_1/data/sources/init_firebase_data/init_firebase_data.dart';
import 'package:flutter_application_1/data/sources/room/room_firebase_service.dart';
import 'package:flutter_application_1/domain/repository/building/building.dart';
import 'package:flutter_application_1/domain/repository/room/room.dart';
import 'package:flutter_application_1/domain/usecases/auth/sigin.dart';
import 'package:flutter_application_1/domain/usecases/auth/signup.dart';
import 'package:flutter_application_1/domain/usecases/auth/forgot_password.dart';
import 'package:flutter_application_1/domain/usecases/building/get_building_by_code.dart';
import 'package:flutter_application_1/domain/usecases/building/get_buildings.dart';
import 'package:flutter_application_1/domain/usecases/room/get_available_rooms.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_application_1/data/sources/auth/auth_firebase_service.dart';
import 'package:flutter_application_1/data/repository/auth/auth_repository_impl.dart';
import 'package:flutter_application_1/domain/repository/auth/auth.dart';
import 'package:flutter_application_1/data/repository/booking/booking_repository_impl.dart';
import 'package:flutter_application_1/data/sources/booking/booking_firebase_service.dart';
import 'package:flutter_application_1/domain/repository/booking/booking.dart';
import 'package:flutter_application_1/domain/usecases/booking/create_booking.dart';
import 'package:flutter_application_1/domain/usecases/booking/get_bookings.dart';
import 'package:flutter_application_1/domain/usecases/booking/update_booking.dart';
import 'package:flutter_application_1/domain/usecases/booking/delete_booking.dart';

final sl = GetIt.instance;

Future<void> initializeDependencies() async {
  // Register Firebase Firestore
  sl.registerLazySingleton(() => FirebaseFirestore.instance);

  // Register Firebase data initializer
  sl.registerSingleton<InitFirebaseData>(InitFirebaseData());
  
  // Initialize Firebase data
  await sl<InitFirebaseData>().initializeData();
  
  // Register services
  sl.registerSingleton<AuthFirebaseService>(AuthFirebaseServiceImpl());
  sl.registerSingleton<BookingFirebaseService>(BookingFirebaseServiceImpl());
  sl.registerSingleton<BuildingFirebaseService>(BuildingFirebaseServiceImpl());
  sl.registerSingleton<RoomFirebaseService>(RoomFirebaseServiceImpl());
  
  // Register repositories
  sl.registerSingleton<AuthRepository>(AuthRepositoryImpl());
  sl.registerSingleton<BookingRepository>(BookingRepositoryImpl());
  sl.registerSingleton<BuildingRepository>(BuildingRepositoryImpl());
  sl.registerSingleton<RoomRepository>(RoomRepositoryImpl());
  
  // Register use cases
  sl.registerSingleton<SignupUseCase>(SignupUseCase());
  sl.registerSingleton<SigninUseCase>(SigninUseCase());
  sl.registerSingleton<ForgotPasswordUseCase>(ForgotPasswordUseCase());
  sl.registerSingleton<CreateBookingUseCase>(CreateBookingUseCase());
  sl.registerSingleton<GetBuildingsUseCase>(GetBuildingsUseCase());
  sl.registerSingleton<GetAvailableRoomsUseCase>(GetAvailableRoomsUseCase());
  sl.registerSingleton<GetBuildingByCodeUseCase>(GetBuildingByCodeUseCase());
  sl.registerSingleton<GetBookingsUseCase>(GetBookingsUseCase());
  sl.registerSingleton<UpdateBookingUseCase>(UpdateBookingUseCase());
  sl.registerSingleton<DeleteBookingUseCase>(DeleteBookingUseCase());
}