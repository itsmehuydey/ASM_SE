import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/configs/theme/app_colors.dart';
import 'package:flutter_application_1/data/models/booking/booking_request.dart';
import 'package:flutter_application_1/presentation/root/pages/root.dart';
import 'package:flutter_application_1/presentation/root/pages/notifications_page.dart';
import 'package:flutter_application_1/presentation/root/pages/account_page.dart';
import 'package:flutter_application_1/presentation/root/pages/settings_page.dart';
import 'package:flutter_application_1/presentation/checkin_page/pages/enter_code_page.dart';
import 'package:flutter_application_1/presentation/booking/pages/booking_pages.dart';
import 'package:intl/intl.dart';

class CheckInPage extends StatefulWidget {
  const CheckInPage({super.key});

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<BookingRequest> _bookings = [];

  @override
  void initState() {
    super.initState();
    _fetchConfirmedBookings();
  }

  Future<void> _fetchConfirmedBookings() async {
    setState(() {
      _isLoading = true;
    });

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: currentUser.uid)
        .where('status', whereIn: ['confirmed', 'checked_in'])
        .get();

    setState(() {
      _bookings = snapshot.docs
          .map((doc) => BookingRequest.fromJson(doc.data()))
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _handleCheckIn(BookingRequest booking) async {
    if (booking.checkInCode == null || booking.checkInCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy mã nhận phòng. Vui lòng liên hệ quản lý.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnterCodePage(
          booking: booking,
          correctCode: booking.checkInCode!,
        ),
      ),
    );

    if (result == true) {
      await _fetchConfirmedBookings();
    }
  }

  Future<void> _terminateBooking(BookingRequest booking) async {
    final docId = '${booking.userId}_${booking.roomNumber}_${booking.bookingDate.toIso8601String()}';
    final roomDocId = '${booking.buildingCode}_${booking.roomNumber.replaceAll('.', '_')}';

    // Kiểm tra xem booking có tồn tại không
    final bookingSnapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .doc(docId)
        .get();

    if (!bookingSnapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đặt phòng không tồn tại. Vui lòng thử lại.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Kiểm tra xem phòng có tồn tại không
    final roomSnapshot = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomDocId)
        .get();

    if (!roomSnapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phòng không tồn tại. Vui lòng thử lại.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Cập nhật trạng thái booking thành 'available' và xóa mã nhận phòng
    await FirebaseFirestore.instance.collection('bookings').doc(docId).update({
      'status': 'available',
      'checkInCode': FieldValue.delete(),
    });

    // Cập nhật trạng thái phòng thành 'available'
    await FirebaseFirestore.instance.collection('rooms').doc(roomDocId).update({
      'status': 'available',
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã hủy đặt phòng thành công!'),
        backgroundColor: Colors.green,
      ),
    );

    await _fetchConfirmedBookings();
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
          'Nhận Phòng',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
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
          : _bookings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.event_busy,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Không có đặt phòng nào để nhận phòng.',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const BookingPage()),
                          );
                        },
                        child: const Text('Đặt phòng ngay'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bookings.length,
                  itemBuilder: (context, index) {
                    final booking = _bookings[index];
                    final isCheckedIn = booking.status == 'checked_in';
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.blue, width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.amber,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    booking.roomNumber,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Tòa ${booking.buildingCode}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isCheckedIn ? Colors.green : Colors.blue,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isCheckedIn ? 'Đã nhận phòng' : 'Đã xác nhận',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 8),
                            _buildInfoRow('Ngày:',
                                DateFormat('dd/MM/yyyy').format(booking.bookingDate)),
                            _buildInfoRow('Thời gian:',
                                '${booking.startTime.format(context)} - ${booking.endTime.format(context)}'),
                            _buildInfoRow('Thời lượng:', '${booking.duration} giờ'),
                            _buildInfoRow('Số người:', '${booking.numberOfPeople}'),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (!isCheckedIn)
                                  ElevatedButton(
                                    onPressed: () => _handleCheckIn(booking),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('Xác nhận nhận phòng'),
                                  ),
                                if (!isCheckedIn) const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => _terminateBooking(booking),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Thoát'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
          const SizedBox(width: 8),
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
}