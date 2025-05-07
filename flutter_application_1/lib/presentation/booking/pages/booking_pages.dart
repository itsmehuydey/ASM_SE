import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/configs/theme/app_colors.dart';
import 'package:flutter_application_1/core/configs/assets/app_images.dart';
import 'package:flutter_application_1/data/models/building/building.dart';
import 'package:flutter_application_1/domain/usecases/building/get_buildings.dart';
import 'package:flutter_application_1/presentation/booking/pages/building_detail_pages.dart';
import 'package:flutter_application_1/presentation/root/pages/root.dart';
import 'package:flutter_application_1/service_locator.dart';
import 'package:intl/intl.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final TextEditingController _buildingController = TextEditingController();
  final TextEditingController _peopleController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _duration = 2;

  bool _showResults = false;
  bool _isLoading = true;
  String _errorMessage = '';

  List<Building> _buildings = [];

  @override
  void initState() {
    super.initState();
    _fetchBuildings();
  }

  Future<void> _fetchBuildings() async {
    setState(() {
      _isLoading = true;
    });

    final result = await sl<GetBuildingsUseCase>().call(null);

    result.fold(
      (error) {
        setState(() {
          _errorMessage = error;
          _isLoading = false;
        });
      },
      (buildings) {
        setState(() {
          _buildings = buildings;
          _isLoading = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _buildingController.dispose();
    _peopleController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final now = DateTime.now();
    final minimumTime = DateTime.now().add(const Duration(minutes: 15));

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedTime) {
      // Kiểm tra nếu phút không phải là bội số của 15
      final int minutes = ((picked.minute + 2) ~/ 5) * 5;
      final roundedTime = TimeOfDay(
        hour: picked.hour + (minutes >= 60 ? 1 : 0),
        minute: minutes >= 60 ? minutes - 60 : minutes,
      );

      // Tạo DateTime từ ngày đã chọn (hoặc ngày hiện tại nếu chưa chọn) và thời gian đã chọn
      final selectedDateTime = DateTime(
        _selectedDate?.year ?? now.year,
        _selectedDate?.month ?? now.month,
        _selectedDate?.day ?? now.day,
        roundedTime.hour,
        roundedTime.minute,
      );

      // Kiểm tra nếu thời gian đã chọn < thời gian tối thiểu
      if (selectedDateTime.isBefore(minimumTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn thời gian sau thời điểm hiện tại ít nhất 15 phút'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _selectedTime = roundedTime;
      });
    }
  }

  void _handleSearch() {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng chọn ngày đặt phòng')),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng chọn thời gian')),
      );
      return;
    }

    if (_peopleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng nhập số người')),
      );
      return;
    }

    final numberOfPeople = int.tryParse(_peopleController.text) ?? 0;
    if (numberOfPeople <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Số người phải lớn hơn 0')),
      );
      return;
    }

    if (numberOfPeople > 60) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Số người không được vượt quá 60')),
      );
      return;
    }

    setState(() {
      _showResults = true;
    });
  }

  void _onBuildingTap(String buildingCode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BuildingDetailPage(
          buildingCode: buildingCode,
          selectedDate: _selectedDate ?? DateTime.now(),
          selectedTime: _selectedTime ?? TimeOfDay.now(),
          numberOfPeople: int.tryParse(_peopleController.text) ?? 1,
          duration: _duration, // Truyền duration
        ),
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
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => RootPage()),
            );
          },
        ),
        title: Text('Đặt phòng', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {},
          ),
          CircleAvatar(
            radius: 16,
            backgroundImage: AssetImage('assets/images/profile_placeholder.png'),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text('Lỗi: $_errorMessage'))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Center(
                        child: Image.asset(
                          AppImages.iconic_logo,
                          height: 40,
                          width: 40,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(20),
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
                                    icon: Icons.calendar_today,
                                    hint: 'Ngày đến',
                                    value:
                                        _selectedDate != null ? DateFormat('dd/MM/yyyy').format(_selectedDate!) : null,
                                    onTap: () => _selectDate(context),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildSearchField(
                                    icon: Icons.access_time,
                                    hint: 'Thời gian',
                                    value: _selectedTime != null ? _selectedTime!.format(context) : null,
                                    onTap: () => _selectTime(context),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSearchField(
                                    icon: Icons.people,
                                    hint: 'Số người',
                                    controller: _peopleController,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildSearchField(
                                    icon: Icons.timer,
                                    hint: 'Thời lượng',
                                    value: '$_duration giờ',
                                    onTap: () {
                                      showModalBottomSheet(
                                        context: context,
                                        builder: (context) => Container(
                                          padding: const EdgeInsets.all(16),
                                          height: 200,
                                          child: Column(
                                            children: [
                                              const Text(
                                                'Chọn thời lượng (giờ)',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              Expanded(
                                                child: ListView.builder(
                                                  scrollDirection: Axis.horizontal,
                                                  itemCount: 8,
                                                  itemBuilder: (context, index) {
                                                    final duration = index + 1;
                                                    return Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                                      child: ChoiceChip(
                                                        label: Text('$duration giờ'),
                                                        selected: _duration == duration,
                                                        onSelected: (selected) {
                                                          if (selected) {
                                                            setState(() {
                                                              _duration = duration;
                                                            });
                                                            Navigator.pop(context);
                                                          }
                                                        },
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _handleSearch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'Tìm kiếm',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 5),
                            Icon(Icons.search),
                          ],
                        ),
                      ),
                      if (_showResults) ...[
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chọn tòa nhà',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 10),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 15,
                                  mainAxisSpacing: 15,
                                  childAspectRatio: 1.5,
                                ),
                                itemCount: _buildings.length,
                                itemBuilder: (context, index) {
                                  final building = _buildings[index];

                                  return GestureDetector(
                                    onTap: () => _onBuildingTap(building.buildingCode),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.amber,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.grey.withOpacity(0.3),
                                            spreadRadius: 1,
                                            blurRadius: 3,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            building.buildingCode,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            building.name,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildSearchField({
    required IconData icon,
    required String hint,
    TextEditingController? controller,
    String? value,
    TextInputType? keyboardType,
    VoidCallback? onTap,
    bool enabled = true,
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
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: enabled && onTap != null && controller == null
                      ? Text(
                          value ?? hint,
                          style: TextStyle(
                            color: value != null ? Colors.black : Colors.grey,
                            fontSize: 14,
                          ),
                        )
                      : TextField(
                          controller: controller,
                          keyboardType: keyboardType,
                          enabled: enabled,
                          decoration: InputDecoration(
                            hintText: hint,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                            hintStyle: const TextStyle(fontSize: 14),
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
