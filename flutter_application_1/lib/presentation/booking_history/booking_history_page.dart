import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/configs/theme/app_colors.dart';
import 'package:flutter_application_1/data/models/booking/booking_request.dart';
import 'package:flutter_application_1/domain/repository/booking/booking.dart';
import 'package:flutter_application_1/presentation/root/pages/root.dart';
import 'package:flutter_application_1/service_locator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/presentation/choose_mode/pages/choose_mode.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BookingHistoryPage extends StatefulWidget {
  const BookingHistoryPage({Key? key}) : super(key: key);

  @override
  State<BookingHistoryPage> createState() => _BookingHistoryPageState();
}

class _BookingHistoryPageState extends State<BookingHistoryPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Stream<List<BookingRequest>>? _bookingsStream;

  @override
  void initState() {
    super.initState();
    _initBookingsStream();
  }

  void _initBookingsStream() {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      _bookingsStream = sl<BookingRepository>().streamUserBookings(currentUser.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('Lịch sử đặt phòng', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => RootPage()),
            );
          },
        ),
      ),
      body: _auth.currentUser == null
          ? _buildNotLoggedIn()
          : _buildBookingsList(),
    );
  }

  Widget _buildNotLoggedIn() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Vui lòng đăng nhập để xem lịch sử đặt phòng',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            child: Text('Đăng nhập'),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsList() {
    return StreamBuilder<List<BookingRequest>>(
      stream: _bookingsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Đã xảy ra lỗi khi tải dữ liệu',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final bookings = snapshot.data ?? [];

        if (bookings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Bạn chưa có lịch sử đặt phòng nào',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => RootPage()),
                    );
                  },
                  child: Text('Đặt phòng ngay'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];

            return Card(
              elevation: 3,
              margin: EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _getStatusColor(booking.status ?? 'pending'),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            booking.roomNumber,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Tòa ${booking.buildingCode}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(booking.status ?? 'pending'),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getStatusText(booking.status ?? 'pending'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Divider(),
                    SizedBox(height: 8),
                    _buildInfoRow('Ngày:', DateFormat('dd/MM/yyyy').format(booking.bookingDate)),
                    _buildInfoRow('Thời gian:', '${booking.startTime.format(context)} - ${booking.endTime.format(context)}'),
                    _buildInfoRow('Thời lượng:', '${booking.duration} giờ'),
                    _buildInfoRow('Số người:', '${booking.numberOfPeople}'),
                    SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (_canCancel(booking.status ?? 'pending')) ...[
                            OutlinedButton(
                              onPressed: () => _showCancelDialog(booking),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey,
                                side: BorderSide(color: Colors.grey),
                              ),
                              child: Text('Hủy đặt phòng'),
                            ),
                            SizedBox(width: 12),
                          ],
                          // OutlinedButton(
                          //   onPressed: () => _showDeleteDialog(booking),
                          //   style: OutlinedButton.styleFrom(
                          //     foregroundColor: Colors.black54,
                          //     side: BorderSide(color: Colors.black54),
                          //   ),
                          //   child: Text('Xóa'),
                          // ),
                          SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () => _showBookingDetailsDialog(booking),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: Text('Xem chi tiết'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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

  Future<void> _showBookingDetailsDialog(BookingRequest booking) async {
    final userDisplay = booking.userName != null && booking.userName!.isNotEmpty
        ? '${booking.userName} (${booking.userEmail})'
        : booking.userEmail;

    await showDialog(
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
              _buildInfoRow('Trạng thái:', _getStatusText(booking.status ?? 'pending'), _getStatusColor(booking.status ?? 'pending')),
              _buildInfoRow('Ngày đặt:', DateFormat('dd/MM/yyyy').format(booking.bookingDate)),
              _buildInfoRow('Thời gian:', '${booking.startTime.format(context)} - ${booking.endTime.format(context)}'),
              _buildInfoRow('Thời lượng:', '${booking.duration} giờ'),
              _buildInfoRow('Số người:', '${booking.numberOfPeople}'),
              _buildInfoRow('Ngày tạo:', booking.createdAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(booking.createdAt!) : 'Không có dữ liệu'),
              _buildInfoRow('Người đặt:', userDisplay),
              if (booking.status != 'pending')
                _buildInfoRow('Mã nhận phòng:', booking.checkInCode ?? 'Chưa có mã'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng'),
          ),
        ],
      ),
    );
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
        return Colors.grey; // Màu xám cho trạng thái hủy
      case 'available':
        return Colors.red; // Màu đỏ cho trạng thái thoát phòng
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
        return 'Không xác định';
    }
  }

  bool _canCancel(String status) {
    return status == 'pending' || status == 'confirmed';
  }

  Future<void> _showCancelDialog(BookingRequest booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận hủy đặt phòng'),
        content: Text('Bạn có chắc chắn muốn hủy đặt phòng ${booking.roomNumber} vào ngày ${DateFormat('dd/MM/yyyy').format(booking.bookingDate)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Không'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
            ),
            child: Text('Xác nhận hủy'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final docId = '${booking.userId}_${booking.roomNumber}_${booking.bookingDate.toIso8601String()}';
      final roomDocId = '${booking.buildingCode}_${booking.roomNumber.replaceAll('.', '_')}';
      final docSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(docId)
          .get();

      if (!docSnapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đặt phòng không tồn tại. Vui lòng thử lại.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Cập nhật trạng thái thành 'cancelled' thay vì 'available'
      await FirebaseFirestore.instance.collection('bookings').doc(docId).update({
        'status': 'cancelled',
        'checkInCode': FieldValue.delete(),
      });

      // Cập nhật trạng thái phòng thành 'available'
      final roomSnapshot = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomDocId)
          .get();

      if (roomSnapshot.exists) {
        await FirebaseFirestore.instance.collection('rooms').doc(roomDocId).update({
          'status': 'available',
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã hủy đặt phòng thành công'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Future<void> _showDeleteDialog(BookingRequest booking) async {
  //   final confirmed = await showDialog<bool>(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: Text('Xác nhận xóa lịch sử đặt phòng'),
  //       content: Text('Bạn có chắc chắn muốn xóa lịch sử đặt phòng ${booking.roomNumber} vào ngày ${DateFormat('dd/MM/yyyy').format(booking.bookingDate)}? Hành động này không thể hoàn tác.'),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context, false),
  //           child: Text('Không'),
  //         ),
  //         ElevatedButton(
  //           onPressed: () => Navigator.pop(context, true),
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: Colors.red,
  //           ),
  //           child: Text('Xác nhận xóa'),
  //         ),
  //       ],
  //     ),
  //   );

  //   if (confirmed == true) {
  //     final docId = '${booking.userId}_${booking.roomNumber}_${booking.bookingDate.toIso8601String()}';
  //     final docSnapshot = await FirebaseFirestore.instance
  //         .collection('bookings')
  //         .doc(docId)
  //         .get();

  //     if (!docSnapshot.exists) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text('Đặt phòng không tồn tại. Vui lòng thử lại.'),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //       return;
  //     }

  //     // Xóa hoàn toàn booking khỏi Firestore
  //     await FirebaseFirestore.instance.collection('bookings').doc(docId).delete();

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text('Đã xóa lịch sử đặt phòng thành công'),
  //         backgroundColor: Colors.green,
  //       ),
  //     );
  //   }
  // }
}