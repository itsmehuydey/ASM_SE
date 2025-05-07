import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/configs/theme/app_colors.dart';
import 'package:flutter_application_1/presentation/root/pages/root.dart';
import 'account_page.dart';
import 'settings_page.dart';
import 'package:intl/intl.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final currentUser = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Thông Báo',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {},
          ),
          const CircleAvatar(
            radius: 16,
            backgroundImage: AssetImage('assets/images/profile_placeholder.png'),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: currentUser == null
          ? const Center(child: Text('Vui lòng đăng nhập để xem thông báo.'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  print('Firestore error in NotificationsPage: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Đã xảy ra lỗi khi tải thông báo.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Lỗi: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () {
                            (context as Element).markNeedsBuild();
                          },
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  );
                }

                final notifications = snapshot.data?.docs ?? [];

                // Sort notifications by createdAt in descending order (newest first)
                notifications.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aCreatedAt = (aData['createdAt'] as Timestamp).toDate();
                  final bCreatedAt = (bData['createdAt'] as Timestamp).toDate();
                  return bCreatedAt.compareTo(aCreatedAt);
                });

                // Limit to 20 notifications
                final limitedNotifications = notifications.take(20).toList();

                // Delete excess notifications if necessary
                _manageNotifications(currentUser.uid, notifications);

                if (limitedNotifications.isEmpty) {
                  return const Center(child: Text('Không có thông báo mới.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20.0),
                  itemCount: limitedNotifications.length,
                  itemBuilder: (context, index) {
                    final notification = limitedNotifications[index].data() as Map<String, dynamic>;
                    final message = notification['message'] as String;
                    final createdAt = (notification['createdAt'] as Timestamp).toDate();
                    final isRead = notification['isRead'] as bool;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      color: isRead ? Colors.grey[200] : Colors.white,
                      child: ListTile(
                        leading: Icon(
                          Icons.notifications,
                          color: isRead ? Colors.grey : AppColors.primary,
                        ),
                        title: Text(
                          message,
                          style: TextStyle(
                            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(createdAt),
                          style: const TextStyle(color: Colors.grey),
                        ),
                        onTap: () async {
                          await FirebaseFirestore.instance
                              .collection('notifications')
                              .doc(limitedNotifications[index].id)
                              .update({'isRead': true});
                        },
                      ),
                    );
                  },
                );
              },
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
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

  Future<void> _manageNotifications(String userId, List<QueryDocumentSnapshot> notifications) async {
    if (notifications.length > 20) {
      final notificationsToDelete = notifications.sublist(20);
      for (var doc in notificationsToDelete) {
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(doc.id)
            .delete();
      }
      print('Deleted ${notificationsToDelete.length} old notifications');
    }
  }
}
