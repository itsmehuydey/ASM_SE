// /// TOI THOI GIAN TU HUY PHONG
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/configs/theme/app_colors.dart';
import 'package:flutter_application_1/data/models/booking/booking_request.dart';
import 'package:flutter_application_1/domain/usecases/booking/get_bookings.dart';
import 'package:flutter_application_1/domain/usecases/booking/update_booking.dart';
import 'package:flutter_application_1/presentation/root/pages/root.dart';
import 'package:flutter_application_1/presentation/root/pages/notifications_page.dart';
import 'package:flutter_application_1/presentation/root/pages/account_page.dart';
import 'package:flutter_application_1/presentation/root/pages/settings_page.dart';
import 'package:flutter_application_1/service_locator.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'room_map_page.dart'; // Import file mới

class RoomManagementPage extends StatefulWidget {
  const RoomManagementPage({super.key});

  @override
  State<RoomManagementPage> createState() => _RoomManagementPageState();
}

class _RoomManagementPageState extends State<RoomManagementPage> {
  final TextEditingController _buildingController = TextEditingController();
  DateTime? _selectedDate;
  bool _isLoading = true;
  String _errorMessage = '';
  List<BookingRequest> _bookings = [];

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  @override
  void dispose() {
    _buildingController.dispose();
    super.dispose();
  }

  Future<void> _fetchBookings() async {
    setState(() {
      _isLoading = true;
    });

    final result = await sl<GetBookingsUseCase>().call(null);

    result.fold(
      (error) {
        setState(() {
          _errorMessage = error;
          _isLoading = false;
        });
      },
      (bookings) async {
        for (var booking in bookings) {
          if (await _isBookingExpired(booking)) {
            await _terminateBooking(booking, auto: true);
          }
        }

        final updatedResult = await sl<GetBookingsUseCase>().call(null);
        updatedResult.fold(
          (error) {
            setState(() {
              _errorMessage = error;
              _isLoading = false;
            });
          },
          (updatedBookings) {
            setState(() {
              _bookings = updatedBookings;
              _isLoading = false;
            });
          },
        );
      },
    );
  }

  Future<bool> _isBookingExpired(BookingRequest booking) async {
    final startDateTime = DateTime(
      booking.bookingDate.year,
      booking.bookingDate.month,
      booking.bookingDate.day,
      booking.startTime.hour,
      booking.startTime.minute,
    );
    final endDateTime = startDateTime.add(Duration(hours: booking.duration));
    final now = DateTime.now();

    return now.isAfter(endDateTime) && (booking.status == 'confirmed' || booking.status == 'checked_in');
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _filterBookings();
    }
  }

  void _filterBookings() {
    setState(() {
      _isLoading = true;
    });

    sl<GetBookingsUseCase>().call(null).then((result) {
      result.fold(
        (error) {
          setState(() {
            _errorMessage = error;
            _isLoading = false;
          });
        },
        (bookings) {
          setState(() {
            _bookings = bookings.where((booking) {
              bool matchesBuilding = _buildingController.text.isEmpty ||
                  booking.buildingCode.toLowerCase().contains(_buildingController.text.toLowerCase());
              bool matchesDate = _selectedDate == null ||
                  (booking.bookingDate.day == _selectedDate!.day &&
                      booking.bookingDate.month == _selectedDate!.month &&
                      booking.bookingDate.year == _selectedDate!.year);
              return matchesBuilding && matchesDate;
            }).toList();
            _isLoading = false;
          });
        },
      );
    });
  }

  Future<void> _createNotification(String userId, String message) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': userId,
      'message': message,
      'isRead': false,
      'createdAt': Timestamp.now(),
    });
  }

  String _generateCheckInCode() {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(5, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  Future<void> _confirmBooking(BookingRequest booking) async {
    final docId = '${booking.userId}_${booking.roomNumber}_${booking.bookingDate.toIso8601String()}';
    final docSnapshot = await FirebaseFirestore.instance.collection('bookings').doc(docId).get();

    if (!docSnapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đặt phòng không tồn tại. Vui lòng tạo lại.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final checkInCode = _generateCheckInCode();

    final updatedBooking = BookingRequest(
      userId: booking.userId,
      userName: booking.userName,
      userEmail: booking.userEmail,
      buildingCode: booking.buildingCode,
      roomNumber: booking.roomNumber,
      floor: booking.floor,
      bookingDate: booking.bookingDate,
      startTime: booking.startTime,
      duration: booking.duration,
      numberOfPeople: booking.numberOfPeople,
      status: 'confirmed',
      checkInCode: checkInCode,
    );

    final result = await sl<UpdateBookingUseCase>().call(updatedBooking);

    result.fold(
      (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xác nhận: $error')),
        );
      },
      (_) async {
        await _createNotification(
          booking.userId,
          'Đặt phòng ${booking.roomNumber} tại ${booking.buildingCode} vào ${DateFormat('dd/MM/yyyy').format(booking.bookingDate)} đã được xác nhận. Mã nhận phòng: $checkInCode',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Xác nhận đặt phòng thành công!'),
            backgroundColor: Colors.green,
          ),
        );

        await Future.delayed(const Duration(seconds: 2));
        await _fetchBookings();
      },
    );
  }

  Future<void> _extendBooking(BookingRequest booking) async {
    final docId = '${booking.userId}_${booking.roomNumber}_${booking.bookingDate.toIso8601String()}';
    final docSnapshot = await FirebaseFirestore.instance.collection('bookings').doc(docId).get();

    if (!docSnapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đặt phòng không tồn tại. Vui lòng tạo lại.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final newDuration = booking.duration + 1;
    final updatedBooking = BookingRequest(
      userId: booking.userId,
      userName: booking.userName,
      userEmail: booking.userEmail,
      buildingCode: booking.buildingCode,
      roomNumber: booking.roomNumber,
      floor: booking.floor,
      bookingDate: booking.bookingDate,
      startTime: booking.startTime,
      duration: newDuration,
      numberOfPeople: booking.numberOfPeople,
      status: booking.status,
      checkInCode: booking.checkInCode,
    );

    final result = await sl<UpdateBookingUseCase>().call(updatedBooking);

    result.fold(
      (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gia hạn: $error')),
        );
      },
      (_) async {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gia hạn thời gian thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
        await _fetchBookings();
      },
    );
  }

  Future<void> _terminateBooking(BookingRequest booking, {bool auto = false}) async {
    final docId = '${booking.userId}_${booking.roomNumber}_${booking.bookingDate.toIso8601String()}';
    final roomDocId = '${booking.buildingCode}_${booking.roomNumber.replaceAll('.', '_')}';

    final docSnapshot = await FirebaseFirestore.instance.collection('bookings').doc(docId).get();

    if (!docSnapshot.exists) {
      if (!auto) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đặt phòng không tồn tại. Vui lòng tạo lại.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    await FirebaseFirestore.instance.collection('bookings').doc(docId).update({
      'status': 'cancelled',
      'checkInCode': FieldValue.delete(),
    });

    final roomSnapshot = await FirebaseFirestore.instance.collection('rooms').doc(roomDocId).get();

    if (roomSnapshot.exists) {
      await FirebaseFirestore.instance.collection('rooms').doc(roomDocId).update({
        'status': 'available',
      });
    }

    if (auto) {
      await _createNotification(
        booking.userId,
        'Đặt phòng ${booking.roomNumber} tại ${booking.buildingCode} đã tự động kết thúc do hết thời gian.',
      );
    } else {
      await _createNotification(
        booking.userId,
        'Đặt phòng ${booking.roomNumber} tại ${booking.buildingCode} đã được kết thúc bởi quản lý.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kết thúc đặt phòng thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    }
    await Future.delayed(const Duration(seconds: 2));
    await _fetchBookings();
  }

  Future<void> _deleteBooking(BookingRequest booking) async {
    final docId = '${booking.userId}_${booking.roomNumber}_${booking.bookingDate.toIso8601String()}';
    final docSnapshot = await FirebaseFirestore.instance.collection('bookings').doc(docId).get();

    if (!docSnapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đặt phòng không tồn tại. Vui lòng thử lại.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('bookings').doc(docId).delete();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã xóa đặt phòng thành công'),
        backgroundColor: Colors.green,
      ),
    );
    await Future.delayed(const Duration(seconds: 2));
    await _fetchBookings();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'checked_in':
        return Colors.green;
      case 'completed':
        return Colors.purple;
      case 'cancelled':
        return Colors.grey;
      case 'available':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Đang xử lý';
      case 'confirmed':
        return 'Đã xác nhận';
      case 'checked_in':
        return 'Đã nhận phòng';
      case 'completed':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      case 'available':
        return 'Đã thoát phòng';
      default:
        return 'Đã thoát phòng';
    }
  }

  Widget _buildInfoRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: valueColor ?? Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _viewDetails(BookingRequest booking) {
    final userDisplay = booking.userName != null && booking.userName!.isNotEmpty
        ? '${booking.userName} (${booking.userEmail})'
        : booking.userEmail;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chi tiết đặt phòng ${booking.roomNumber}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('Tòa:', booking.buildingCode),
              _buildInfoRow('Phòng:', booking.roomNumber),
              _buildInfoRow('Tầng:', '${booking.floor}'),
              _buildInfoRow('Trạng thái:', _getStatusText(booking.status ?? 'pending'),
                  _getStatusColor(booking.status ?? 'pending')),
              _buildInfoRow('Ngày đặt:', DateFormat('dd/MM/yyyy').format(booking.bookingDate)),
              _buildInfoRow('Thời gian:', booking.startTime.format(context)),
              _buildInfoRow('Thời lượng:', '${booking.duration} giờ'),
              _buildInfoRow('Số người:', '${booking.numberOfPeople}'),
              _buildInfoRow('Người đặt:', userDisplay),
              if (booking.status != 'pending') _buildInfoRow('Mã nhận phòng:', booking.checkInCode ?? 'Chưa có mã'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Quản Lý Phòng',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.map, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RoomMapPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsPage()),
              );
            },
          ),
          const CircleAvatar(
            radius: 16,
            backgroundImage: AssetImage('assets/images/profile_placeholder.png'),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text('Lỗi: $_errorMessage'))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20.0),
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSearchField(
                                    icon: Icons.apartment,
                                    hint: 'Mã tòa',
                                    controller: _buildingController,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildSearchField(
                                    icon: Icons.calendar_today,
                                    hint: 'Ngày đến',
                                    value:
                                        _selectedDate != null ? DateFormat('dd/MM/yyyy').format(_selectedDate!) : null,
                                    onTap: () => _selectDate(context),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _filterBookings,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                  vertical: 15,
                                ),
                              ),
                              child: const Text(
                                'Tìm kiếm',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        itemCount: _bookings.length,
                        itemBuilder: (context, index) {
                          final booking = _bookings[index];
                          return RoomCard(
                            booking: booking,
                            onConfirm: () => _confirmBooking(booking),
                            onExtend: () => _extendBooking(booking),
                            onTerminate: () => _terminateBooking(booking),
                            onDelete: () => _showDeleteDialog(booking),
                            onViewDetails: () => _viewDetails(booking),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: const [
                              StatusIndicator(
                                color: Colors.green,
                                text: 'Đã nhận phòng',
                              ),
                              SizedBox(width: 10),
                              StatusIndicator(
                                color: Colors.orange,
                                text: 'Chưa xác nhận',
                              ),
                              SizedBox(width: 10),
                              StatusIndicator(
                                color: Colors.blue,
                                text: 'Đã xác nhận',
                              ),
                              SizedBox(width: 10),
                              StatusIndicator(
                                color: Colors.grey,
                                text: 'Đã hủy',
                              ),
                              SizedBox(width: 10),
                              StatusIndicator(
                                color: Colors.red,
                                text: 'Đã thoát phòng',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const RootPage()),
                (route) => false,
              );
              break;
            case 1:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsPage()),
              );
              break;
            case 2:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AccountPage()),
              );
              break;
            case 3:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: 'Tin nhắn',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Tài khoản',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField({
    required IconData icon,
    required String hint,
    TextEditingController? controller,
    String? value,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: controller == null
                      ? Text(
                          value ?? hint,
                          style: TextStyle(
                            color: value != null ? Colors.black : Colors.grey,
                            fontSize: 14,
                          ),
                        )
                      : TextField(
                          controller: controller,
                          decoration: InputDecoration(
                            hintText: hint,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                            hintStyle: const TextStyle(fontSize: 14),
                          ),
                          style: const TextStyle(fontSize: 14),
                          onChanged: (value) => _filterBookings(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(BookingRequest booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận trạng thái đặt phòng'),
        content: Text(
            'Bạn có chắc chắn muốn xóa trạng thái đặt phòng ${booking.roomNumber} vào ngày ${DateFormat('dd/MM/yyyy').format(booking.bookingDate)}? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Không'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Xác nhận xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteBooking(booking);
    }
  }
}

class RoomCard extends StatelessWidget {
  final BookingRequest booking;
  final VoidCallback onConfirm;
  final VoidCallback onExtend;
  final VoidCallback onTerminate;
  final VoidCallback onDelete;
  final VoidCallback onViewDetails;

  const RoomCard({
    required this.booking,
    required this.onConfirm,
    required this.onExtend,
    required this.onTerminate,
    required this.onDelete,
    required this.onViewDetails,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isConfirmed = booking.status == 'confirmed';
    final isCheckedIn = booking.status == 'checked_in';
    final isCancelled = booking.status == 'cancelled';
    final isAvailable = booking.status == 'available';
    final statusColor = isCheckedIn
        ? Colors.green
        : isConfirmed
            ? Colors.blue
            : isCancelled
                ? Colors.grey
                : isAvailable
                    ? Colors.red
                    : Colors.orange;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 80,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${booking.buildingCode} ${booking.roomNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ngày: ${DateFormat('dd/MM/yyyy').format(booking.bookingDate)}'),
                    Text('Bắt đầu: ${booking.startTime.format(context)}'),
                    Text('Thời lượng: ${booking.duration} giờ'),
                    Text('Số người: ${booking.numberOfPeople}'),
                  ],
                ),
              ),
              CircleAvatar(radius: 8, backgroundColor: statusColor),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isConfirmed && !isCheckedIn && !isCancelled && !isAvailable)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: TextButton.icon(
                      onPressed: onConfirm,
                      icon: const Icon(Icons.check, color: Colors.green),
                      label: const Text('Confirm', style: TextStyle(color: Colors.green)),
                    ),
                  ),
                if (!isCancelled && !isAvailable)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: TextButton.icon(
                      onPressed: onExtend,
                      icon: const Icon(Icons.timer, color: Colors.blue),
                      label: const Text('Extend', style: TextStyle(color: Colors.blue)),
                    ),
                  ),
                if (!isCancelled && !isAvailable)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: TextButton.icon(
                      onPressed: onTerminate,
                      icon: const Icon(Icons.exit_to_app, color: Colors.grey),
                      label: const Text('Terminate', style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete, color: Colors.black54),
                    label: const Text('Delete', style: TextStyle(color: Colors.black54)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: TextButton.icon(
                    onPressed: onViewDetails,
                    icon: const Icon(Icons.info, color: Colors.black),
                    label: const Text('Details', style: TextStyle(color: Colors.black)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatusIndicator extends StatelessWidget {
  final Color color;
  final String text;

  const StatusIndicator({required this.color, required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(radius: 6, backgroundColor: color),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}