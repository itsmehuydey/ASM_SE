import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/configs/theme/app_colors.dart';
import 'package:flutter_application_1/data/models/booking/booking_request.dart';
import 'package:flutter_application_1/data/sources/room/room_firebase_service.dart';
import 'package:flutter_application_1/presentation/root/pages/root.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class EnterCodePage extends StatefulWidget {
  final BookingRequest booking;
  final String correctCode;

  const EnterCodePage({
    super.key,
    required this.booking,
    required this.correctCode,
  });

  @override
  State<EnterCodePage> createState() => _EnterCodePageState();
}

class _EnterCodePageState extends State<EnterCodePage> {
  final TextEditingController _codeController = TextEditingController();
  final RoomFirebaseService _roomService = RoomFirebaseServiceImpl();
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isCheckedIn = false;

  Future<void> _createNotification(String userId, String message) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'message': message,
        'isRead': false,
        'createdAt': Timestamp.now(),
      });
      print('Notification sent successfully: $message for userId: $userId');
    } catch (e) {
      print('Error sending notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi gửi thông báo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _verifyCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final enteredCode = _codeController.text.trim();
    if (enteredCode != widget.correctCode) {
      setState(() {
        _errorMessage = 'Mã không đúng. Vui lòng thử lại.';
        _isLoading = false;
      });
      return;
    }

    final docId =
        '${widget.booking.userId}_${widget.booking.roomNumber}_${widget.booking.bookingDate.toIso8601String()}';
    final now = DateTime.now();
    final startDateTime = DateTime(
      widget.booking.bookingDate.year,
      widget.booking.bookingDate.month,
      widget.booking.bookingDate.day,
      widget.booking.startTime.hour,
      widget.booking.startTime.minute,
    );
    final endDateTime = startDateTime.add(Duration(hours: widget.booking.duration));

    if (now.isAfter(endDateTime)) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Đã hết thời gian nhận phòng. Vui lòng liên hệ quản lý.';
      });
      return;
    }

    try {
      // Cập nhật trạng thái booking
      await FirebaseFirestore.instance.collection('bookings').doc(docId).update({
        'status': 'checked_in',
        'checkInCode': FieldValue.delete(),
      });

      // Cập nhật trạng thái phòng thành 'occupied' bằng RoomFirebaseService
      final updateResult = await _roomService.updateRoomStatus(
        widget.booking.buildingCode,
        widget.booking.roomNumber,
        'occupied',
      );

      updateResult.fold(
        (error) {
          setState(() {
            _isLoading = false;
            _errorMessage = error;
          });
          return;
        },
        (success) {
          setState(() {
            _isLoading = false;
            _isCheckedIn = true;
          });
        },
      );

      if (!_isCheckedIn) return; // Nếu cập nhật trạng thái phòng thất bại, không gửi thông báo

      final checkInMessage =
          'Bạn đã nhận phòng thành công tại ${widget.booking.roomNumber} vào ${DateFormat('dd/MM/yyyy HH:mm').format(now)}';
      await _createNotification(widget.booking.userId, checkInMessage);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nhận phòng thành công!'),
          backgroundColor: Colors.green,
        ),
      );

      await Future.delayed(const Duration(seconds: 1));
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (context) => const RootPage(message: 'Nhận phòng thành công!')),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Lỗi khi nhận phòng: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi nhận phòng: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _terminateBooking() async {
    setState(() {
      _isLoading = true;
    });

    final docId =
        '${widget.booking.userId}_${widget.booking.roomNumber}_${widget.booking.bookingDate.toIso8601String()}';

    try {
      // Kiểm tra booking có tồn tại không
      final docSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(docId)
          .get();

      if (!docSnapshot.exists) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đặt phòng không tồn tại. Vui lòng thử lại.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Cập nhật trạng thái booking
      print('Updating booking status to available for docId: $docId');
      await FirebaseFirestore.instance.collection('bookings').doc(docId).update({
        'status': 'available',
        'checkInCode': FieldValue.delete(),
      });

      // Cập nhật trạng thái phòng thành 'available' bằng RoomFirebaseService
      print('Updating room status to available');
      final updateResult = await _roomService.updateRoomStatus(
        widget.booking.buildingCode,
        widget.booking.roomNumber,
        'available',
      );

      if (updateResult.isLeft()) {
        final error = updateResult.fold((l) => l, (_) => '');
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Gửi thông báo thoát phòng
      final now = DateTime.now();
      final terminateMessage =
          'Bạn đã thoát phòng ${widget.booking.roomNumber} vào ${DateFormat('dd/MM/yyyy HH:mm').format(now)}';
      print('Preparing to send termination notification for userId: ${widget.booking.userId}');
      await _createNotification(widget.booking.userId, terminateMessage);

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thoát phòng thành công!'),
          backgroundColor: Colors.green,
        ),
      );

      await Future.delayed(const Duration(seconds: 1));
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (context) => const RootPage(message: 'Thoát phòng thành công!')),
        (route) => false,
      );
    } catch (e) {
      print('Error in _terminateBooking: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi thoát phòng: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
void initState() {
  super.initState();
  _checkIfAlreadyCheckedIn();
}

Future<void> _checkIfAlreadyCheckedIn() async {
  final docId =
      '${widget.booking.userId}_${widget.booking.roomNumber}_${widget.booking.bookingDate.toIso8601String()}';

  final docSnapshot = await FirebaseFirestore.instance
      .collection('bookings')
      .doc(docId)
      .get();

  if (docSnapshot.exists) {
    final data = docSnapshot.data();
    if (data != null && data['status'] == 'checked_in') {
      setState(() {
        _isCheckedIn = true;
      });
    }
  }
}

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
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
          'Nhập Mã Nhận Phòng',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height -
                      AppBar().preferredSize.height -
                      MediaQuery.of(context).padding.top -
                      kBottomNavigationBarHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Card(
                          elevation: 3,
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
                                        widget.booking.roomNumber,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Tòa ${widget.booking.buildingCode}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(),
                                const SizedBox(height: 8),
                                _buildInfoRow('Ngày:', DateFormat('dd/MM/yyyy')
                                    .format(widget.booking.bookingDate)),
                                _buildInfoRow('Thời gian:',
                                    '${widget.booking.startTime.format(context)} - ${widget.booking.endTime.format(context)}'),
                                _buildInfoRow(
                                    'Thời lượng:', '${widget.booking.duration} giờ'),
                                _buildInfoRow(
                                    'Số người:', '${widget.booking.numberOfPeople}'),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Quét mã QR để nhận mã nhận phòng:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: QrImageView(
                          data: widget.correctCode,
                          version: QrVersions.auto,
                          size: 200.0,
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.all(10),
                          errorCorrectionLevel: QrErrorCorrectLevel.L,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Nhập mã nhận phòng:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _codeController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          labelText: 'Mã nhận phòng (5 ký tự)',
                          labelStyle: const TextStyle(color: Colors.grey),
                          errorText: _errorMessage.isNotEmpty ? _errorMessage : null,
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                        maxLength: 5,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: _isCheckedIn ? null : _verifyCode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 40, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 3,
                              ),
                              child: const Text(
                                'Xác nhận',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (_isCheckedIn) ...[
                              const SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: _terminateBooking,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 40, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 3,
                                ),
                                child: const Text(
                                  'Thoát phòng',
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}