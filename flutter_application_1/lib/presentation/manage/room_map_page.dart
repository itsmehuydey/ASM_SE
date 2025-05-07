import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/configs/theme/app_colors.dart';

class RoomMapPage extends StatefulWidget {
  const RoomMapPage({super.key});

  @override
  State<RoomMapPage> createState() => _RoomMapPageState();
}

class _RoomMapPageState extends State<RoomMapPage> {
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _bookings = [];
  Map<String, double> _statusPercentages = {
    'pending': 0.0,
    'confirmed': 0.0,
    'checked_in': 0.0,
    'available': 0.0,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Lấy tất cả các phòng từ collection 'rooms'
      final QuerySnapshot roomSnapshot =
          await FirebaseFirestore.instance.collection('rooms').get();
      _rooms = roomSnapshot.docs.map((doc) => {
        ...doc.data() as Map<String, dynamic>,
        'id': doc.id,
        'status': 'available' // Mặc định trạng thái là available nếu không có booking
      }).toList();

      // Lấy danh sách đặt phòng từ collection 'bookings'
      final QuerySnapshot bookingSnapshot =
          await FirebaseFirestore.instance.collection('bookings').get();
      _bookings = bookingSnapshot.docs
          .map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id})
          .toList();

      // Gán trạng thái từ bookings vào rooms
      for (var booking in _bookings) {
        final roomIndex = _rooms.indexWhere((room) => room['roomNumber'] == booking['roomNumber']);
        if (roomIndex != -1) {
          _rooms[roomIndex]['status'] = booking['status'] ?? 'available';
        }
      }

      final totalRooms = _rooms.length.toDouble();
      final statusCount = {
        'pending': _rooms.where((room) => room['status'] == 'pending').length,
        'confirmed': _rooms.where((room) => room['status'] == 'confirmed').length,
        'checked_in': _rooms.where((room) => room['status'] == 'checked_in').length,
        'available': _rooms.where((room) => ['available', 'cancelled', 'checked_out'].contains(room['status'])).length,
      };

      _statusPercentages = {
        'pending': totalRooms > 0 ? (statusCount['pending']! / totalRooms) * 100 : 0.0,
        'confirmed': totalRooms > 0 ? (statusCount['confirmed']! / totalRooms) * 100 : 0.0,
        'checked_in': totalRooms > 0 ? (statusCount['checked_in']! / totalRooms) * 100 : 0.0,
        'available': totalRooms > 0 ? (statusCount['available']! / totalRooms) * 100 : 0.0,
      };

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'checked_in':
        return Colors.green;
      case 'available':
      case 'cancelled': // Gộp cancelled vào available
      case 'checked_out': // Gộp checked_in vào available
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Room usage statistics'),
        backgroundColor: AppColors.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'Room occupancy rate by status',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text('Pending: ${_statusPercentages['pending']!.toStringAsFixed(1)}%'),
                      Text('Confirmed: ${_statusPercentages['confirmed']!.toStringAsFixed(1)}%'),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text('Checked In: ${_statusPercentages['checked_in']!.toStringAsFixed(1)}%'),
                      Text('Available: ${_statusPercentages['available']!.toStringAsFixed(1)}%'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _rooms.length,
                      itemBuilder: (context, index) {
                        final room = _rooms[index];
                        final status = room['status'] ?? 'available';
                        return Container(
                          decoration: BoxDecoration(
                            color: _getStatusColor(status),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.black, width: 0.5),
                          ),
                          child: Center(
                            child: Text(
                              room['roomNumber'] ?? 'Phòng ${index + 1}',
                              style: const TextStyle(color: Colors.black),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.square, color: Colors.orange),
                      SizedBox(width: 5),
                      Text('Pending'),
                      SizedBox(width: 10),
                      Icon(Icons.square, color: Colors.blue),
                      SizedBox(width: 5),
                      Text('Confirmed'),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.square, color: Colors.green),
                      SizedBox(width: 5),
                      Text('Checked In'),
                      SizedBox(width: 10),
                      Icon(Icons.square, color: Colors.grey),
                      SizedBox(width: 5),
                      Text('Available'),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}