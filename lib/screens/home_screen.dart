import 'package:calamity_report/widgets/emergency_reports_dashboard.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import '../screens/settings_screen.dart';
import '../screens/notification_screen.dart';
import '../screens/notification_list_screen.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../services/weather_service.dart';
import '../widgets/platform_map.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WeatherService _weatherService = WeatherService();
  
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;
  
  Position? _currentPosition;
  Map<String, dynamic>? _weatherData;
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoadingWeather = true;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeInOut,
    );
    _fabController.forward();
    
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoadingWeather = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingWeather = false);
          return;
        }
      }

      _currentPosition = await Geolocator.getCurrentPosition();
      
      // Load weather data
      final weather = await _weatherService.getWeather(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      
      final alerts = await _weatherService.getAlerts(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      setState(() {
        _weatherData = weather;
        _alerts = alerts;
        _isLoadingWeather = false;
      });
    } catch (e) {
      print('Location error: $e');
      setState(() => _isLoadingWeather = false);
    }
  }

  Future<String?> _fetchUsername(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc['name'];
      }
    } catch (e) {
      debugPrint('Error fetching username: $e');
    }
    return null;
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'おはようございます';
    if (hour < 18) return 'こんにちは';
    return 'こんばんは';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        elevation: 0,
        actions: [
          _buildNotificationIconWithBadge(user),
          const SizedBox(width: 4),
        ],
      ),
      drawer: _buildDrawer(context, user),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
          await _getCurrentLocation();
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Determine if it's a tablet/desktop screen
            final isTablet = constraints.maxWidth > 600;
            final maxWidth = isTablet ? 600.0 : constraints.maxWidth;
            
            return Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(isTablet ? 16 : 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCompactWelcomeCard(user),
                      const SizedBox(height: 12),

                      // Weather & Alert Widget
                      _buildWeatherAlertWidget(),
                      const SizedBox(height: 12),

                      // Notifications Preview
                      _buildCompactNotificationsPreview(user),
                      const SizedBox(height: 12),

                      // Quick Actions Grid
                      _buildQuickActions(context, user),
                      const SizedBox(height: 12),

                      // Emergency Quick Actions
                      _buildEmergencyQuickActions(context, user),
                      const SizedBox(height: 12),

                      // Statistics Dashboard
                      _buildCompactStatisticsDashboard(user),
                      const SizedBox(height: 12),

                      // Disaster Map Widget
                      _buildDisasterMapWidget(user),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: _buildCompactEmergencyFAB(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // More Compact Weather & Alert Widget
  Widget _buildWeatherAlertWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.wb_sunny,
                color: Colors.orange.shade700,
                size: 14,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              '天気・警報情報',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        if (_isLoadingWeather)
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Container(
              height: 90,
              padding: const EdgeInsets.all(12),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          )
        else if (_weatherData != null)
          LayoutBuilder(
            builder: (context, constraints) {
              final isTablet = constraints.maxWidth > 500;
              final fontSize = isTablet ? 26.0 : 22.0; // Increased
              final iconSize = isTablet ? 34.0 : 30.0; // Increased
              
              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade300, Colors.blue.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(12), // Increased from 10
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Weather Header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            _weatherService.getWeatherIcon(
                              _weatherData!['weather'][0]['main']
                            ),
                            style: TextStyle(fontSize: iconSize),
                          ),
                          const SizedBox(width: 10), // Increased from 8
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_weatherData!['main']['temp'].round()}°C',
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    height: 1.0,
                                  ),
                                ),
                                Text(
                                  _weatherData!['weather'][0]['description'],
                                  style: const TextStyle(
                                    fontSize: 12, // Increased from 11
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, 
                                      size: 10, // Increased from 9
                                      color: Colors.white70
                                    ),
                                    const SizedBox(width: 2),
                                    Flexible(
                                      child: Text(
                                        _weatherData!['name'] ?? '現在地',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white70,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 10), // Increased from 8
                      
                      // Weather Details
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildCompactWeatherDetail(
                            Icons.water_drop,
                            '${_weatherData!['main']['humidity']}%',
                            '湿度',
                          ),
                          Container(
                            width: 1,
                            height: 24, // Increased from 20
                            color: Colors.white30,
                          ),
                          _buildCompactWeatherDetail(
                            Icons.air,
                            '${_weatherData!['wind']['speed']}',
                            'm/s',
                          ),
                          Container(
                            width: 1,
                            height: 24, // Increased from 20
                            color: Colors.white30,
                          ),
                          _buildCompactWeatherDetail(
                            Icons.thermostat,
                            '${_weatherData!['main']['feels_like'].round()}°',
                            '体感',
                          ),
                        ],
                      ),
                      
                      // Alerts Section
                      if (_alerts.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Divider(color: Colors.white30, height: 1),
                        const SizedBox(height: 6),
                        ..._alerts.take(2).map((alert) => Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: _getAlertColor(alert['severity']),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Row(
                              children: [
                                Text(alert['icon'], style: const TextStyle(fontSize: 13)),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        alert['title'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                      Text(
                                        alert['description'],
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 9,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
                      ],
                      
                      // Disaster Risk Indicators
                      const SizedBox(height: 8),
                      const Divider(color: Colors.white30, height: 1),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Text(
                            '災害リスク',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10, // Increased from 9
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          _buildCompactRiskIndicator('地震', 'Low', Colors.green),
                          const SizedBox(width: 5),
                          _buildCompactRiskIndicator('台風', 'Mid', Colors.orange),
                          const SizedBox(width: 5),
                          _buildCompactRiskIndicator('豪雨', 'High', Colors.red),
                          const SizedBox(width: 5),
                          _buildCompactRiskIndicator('洪水', 'Low', Colors.green),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          )
        else
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.location_off, size: 26, color: Colors.grey.shade400),
                    const SizedBox(height: 5),
                    Text(
                      '位置情報を取得できません',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCompactWeatherDetail(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 14), // Increased from 12
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12, // Increased from 11
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactRiskIndicator(String label, String level, Color color) {
    return Column(
      children: [
        Container(
          width: 18, // Increased from 16
          height: 18, // Increased from 16
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 9, // Increased from 8
              height: 9, // Increased from 8
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8, // Increased from 7
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

 Color _getAlertColor(String severity) {
    switch (severity) {
      case 'high':
        return Colors.red.shade600;
      case 'medium':
        return Colors.orange.shade600;
      default:
        return Colors.yellow.shade700;
    }
  }
  
  // COMPACT Welcome Card
  Widget _buildCompactWelcomeCard(firebase_auth.User? user) {
    return FutureBuilder<String?>(
      future: user != null ? _fetchUsername(user.uid) : null,
      builder: (context, snapshot) {
        final userName = snapshot.data ?? user?.displayName ?? 'ユーザー';

        final now = DateTime.now();
        final weekdays = ['日', '月', '火', '水', '木', '金', '土'];
        final japaneseDate = '${now.month}月${now.day}日(${weekdays[now.weekday % 7]})';
        final timeString = DateFormat('HH:mm').format(now);

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            padding: const EdgeInsets.all(12), 
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20, 
                  backgroundColor: Colors.white,
                  child: Text(
                    _getInitials(userName),
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11, 
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$userNameさん',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16, 
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Text(
                            japaneseDate,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeString,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
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
  }

  Widget _buildQuickActions(BuildContext context, firebase_auth.User? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.dashboard_customize,
                color: Colors.purple.shade700,
                size: 14,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'クイックアクション',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            
            if (screenWidth > 500) {
              // Grid layout for tablets - 5 items in a row
              return GridView.count(
                crossAxisCount: 5,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.95,
                children: _buildQuickActionItems(context),
              );
            } else {
              // Grid layout for mobile - 5 items in a row
              return GridView.count(
                crossAxisCount: 5,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 6,
                childAspectRatio: 0.9,
                children: _buildQuickActionItems(context),
              );
            }
          },
        ),
      ],
    );
  }

  // Build quick action items list
  List<Widget> _buildQuickActionItems(BuildContext context) {
    return [
      _buildCompactQuickActionCard(
        icon: Icons.contact_emergency,
        label: '緊急連絡先',
        color: Colors.red,
        onTap: () {
          _showEmergencyContactsDialog(context);
        },
      ),
      _buildCompactQuickActionCard(
        icon: Icons.notifications_active,
        label: '通知設定',
        color: Colors.orange,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NotificationScreen(),
            ),
          );
        },
      ),
      _buildCompactQuickActionCard(
        icon: Icons.location_on,
        label: '近くの災害',
        color: Colors.blue,
        onTap: () {
          _showNearbyDisastersDialog(context);
        },
      ),
      _buildCompactQuickActionCard(
        icon: Icons.help,
        label: 'ヘルプ',
        color: Colors.green,
        onTap: () {
          _showHelpSupportDialog(context);
        },
      ),
      _buildCompactQuickActionCard(
        icon: Icons.people_alt,
        label: 'メンバー位置',
        color: Colors.purple,
        onTap: () {
          _showTeamMembersLocationDialog(context);
        },
      ),
    ];
  }

  // Compact Quick Action Card Widget
  Widget _buildCompactQuickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Use same sizing logic as emergency cards
            final size = constraints.biggest;
            final padding = size.width * 0.08;
            
            return Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    flex: 3,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    flex: 1,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: color,
                          height: 1.0, 
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // 1. Emergency Contacts Dialog
  void _showEmergencyContactsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.contact_emergency,
                        color: Colors.red.shade700,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '緊急連絡先一覧',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              // Contacts List
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildEmergencyContactItem(
                      icon: Icons.local_fire_department,
                      title: '消防署',
                      number: '119',
                      description: '火災・救急',
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    _buildEmergencyContactItem(
                      icon: Icons.local_police,
                      title: '警察',
                      number: '110',
                      description: '事件・事故',
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    _buildEmergencyContactItem(
                      icon: Icons.medical_services,
                      title: '救急医療',
                      number: '#7119',
                      description: '医療相談',
                      color: Colors.green,
                    ),
                    const SizedBox(height: 12),
                    _buildEmergencyContactItem(
                      icon: Icons.warning,
                      title: '災害情報',
                      number: '0570-783-189',
                      description: '気象庁',
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 12),
                    _buildEmergencyContactItem(
                      icon: Icons.local_hospital,
                      title: '毒物情報',
                      number: '072-727-2499',
                      description: '中毒110番',
                      color: Colors.purple,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyContactItem({
    required IconData icon,
    required String title,
    required String number,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.phone, color: color, size: 20),
        ],
      ),
    );
  }

  // 2. Nearby Disasters Dialog
  void _showNearbyDisastersDialog(BuildContext context) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.location_on,
                      color: Colors.blue.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '近くの災害',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Nearby Disasters List
            Container(
              constraints: const BoxConstraints(maxHeight: 400),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('emergency_reports')
                    .where('status', isEqualTo: 'pending')
                    .orderBy('createdAt', descending: true)
                    .limit(10)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                          const SizedBox(height: 12),
                          const Text('エラーが発生しました'),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final reports = snapshot.data!.docs;

                  if (reports.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle, size: 48, color: Colors.green.shade400),
                          const SizedBox(height: 12),
                          const Text('近くに災害報告はありません'),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: reports.length,
                    itemBuilder: (context, index) {
                      final data = reports[index].data() as Map<String, dynamic>;
                      return _buildNearbyDisasterItem(data);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyDisasterItem(Map<String, dynamic> data) {
    final type = data['type'] ?? 'その他';
    final description = data['description'] ?? '';
    final timestamp = data['createdAt'] as Timestamp?;
    
    IconData icon;
    Color color;
    
    switch (type) {
      case '火災':
        icon = Icons.local_fire_department;
        color = Colors.red;
        break;
      case '洪水':
        icon = Icons.flood;
        color = Colors.blue;
        break;
      case '地震':
        icon = Icons.terrain;
        color = Colors.orange;
        break;
      case '医療':
        icon = Icons.medical_services;
        color = Colors.green;
        break;
      default:
        icon = Icons.warning;
        color = Colors.purple;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      type,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const Spacer(),
                    if (timestamp != null)
                      Text(
                        DateFormat('MM/dd HH:mm').format(timestamp.toDate()),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 3. Help & Support Dialog
  void _showHelpSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.help,
                        color: Colors.green.shade700,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'ヘルプ・サポート',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              // Help Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHelpSection(
                      icon: Icons.emergency,
                      title: '緊急時の対応',
                      description: '• 冷静に状況を把握する\n'
                          '• 安全な場所に避難する\n'
                          '• 緊急連絡先に連絡する\n'
                          '• アプリから報告する',
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    _buildHelpSection(
                      icon: Icons.report,
                      title: '報告の仕方',
                      description: '1. 緊急報告ボタンをタップ\n'
                          '2. 災害の種類を選択\n'
                          '3. 詳細を入力（最低10文字）\n'
                          '4. 優先度を選択して送信',
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    _buildHelpSection(
                      icon: Icons.notifications,
                      title: '通知について',
                      description: '• 緊急警報を受信できます\n'
                          '• 通知設定で管理できます\n'
                          '• 重要な通知はピン留め可能\n'
                          '• 通知履歴から確認できます',
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    _buildHelpSection(
                      icon: Icons.contact_support,
                      title: 'サポート',
                      description: '質問や問題がある場合は\n'
                          'support@calamity-report.jp\n'
                          'までご連絡ください。',
                      color: Colors.purple,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpSection({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // 4. Team Members Location Dialog
  void _showTeamMembersLocationDialog(BuildContext context) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.people_alt,
                      color: Colors.purple.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'チームメンバーの位置',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Team Members List
            Container(
              constraints: const BoxConstraints(maxHeight: 400),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('isOnline', isEqualTo: true)
                    .limit(20)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                          const SizedBox(height: 12),
                          const Text('エラーが発生しました'),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final members = snapshot.data!.docs
                      .where((doc) => doc.id != user.uid)
                      .toList();

                  if (members.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('オンラインのメンバーはいません'),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final data = members[index].data() as Map<String, dynamic>;
                      return _buildTeamMemberItem(data);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamMemberItem(Map<String, dynamic> data) {
    final name = data['name'] ?? 'Unknown';
    final email = data['email'] ?? '';
    final location = data['lastLocation'] as Map<String, dynamic>?;
    final lastSeen = data['lastSeen'] as Timestamp?;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                backgroundColor: Colors.purple.shade100,
                child: Text(
                  name[0].toUpperCase(),
                  style: TextStyle(
                    color: Colors.purple.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (lastSeen != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '最終: ${DateFormat('HH:mm').format(lastSeen.toDate())}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (location != null)
            Icon(Icons.location_on, color: Colors.purple.shade700, size: 20),
        ],
      ),
    );
  }

  // Notification icon with real-time unread count badge
  Widget _buildNotificationIconWithBadge(firebase_auth.User? user) {
    if (user == null) {
      return IconButton(
        icon: const Icon(Icons.notifications_outlined),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NotificationListScreen(),
            ),
          );
        },
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
        final displayCount = unreadCount > 99 ? '99+' : unreadCount.toString();

        return Stack(
          children: [
            IconButton(
              icon: Icon(
                unreadCount > 0 
                    ? Icons.notifications_active 
                    : Icons.notifications_outlined,
                color: unreadCount > 0 ? Colors.orange : null,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationListScreen(),
                  ),
                );
              },
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    displayCount,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // Statistics Dashboard
  Widget _buildCompactStatisticsDashboard(firebase_auth.User? user) {
    if (user == null) return const SizedBox.shrink();

    return EmergencyReportsDashboard(
      userId: user.uid,
      isCompact: true,
    );
  }

  // Notifications Preview
  Widget _buildCompactNotificationsPreview(firebase_auth.User? user) {
    if (user == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.notifications_active,
                    color: Colors.blue.shade700,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  '通知',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationListScreen(),
                  ),
                );
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'すべて',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('notifications')
              .where('userId', isEqualTo: user.uid)
              .where('read', isEqualTo: false)
              .orderBy('receivedAt', descending: true)
              .limit(1)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade400, size: 16),
                      const SizedBox(width: 8),
                      const Text('エラー', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 32,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '通知なし',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Get unread notifications separately for counting
            return StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('notifications')
                  .where('userId', isEqualTo: user.uid)
                  .where('read', isEqualTo: false)
                  .snapshots(),
              builder: (context, unreadSnapshot) {
                final unreadIds = unreadSnapshot.hasData 
                    ? unreadSnapshot.data!.docs.map((doc) => doc.id).toSet()
                    : <String>{};

                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final isRead = !unreadIds.contains(doc.id);
                    
                    return _buildCompactNotificationCard(data, doc.id, isRead);
                  }).toList(),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildCompactNotificationCard(Map<String, dynamic> data, String docId, bool read) {
    final title = data['title'] ?? '通知';
    final body = data['body'] ?? '';

    return Card(
      elevation: read ? 0 : 1,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      color: read ? Colors.grey.shade50 : Colors.white,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NotificationListScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: read ? Colors.grey.shade200 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.notifications,
                  color: read ? Colors.grey.shade500 : Colors.blue.shade600,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: read ? FontWeight.w500 : FontWeight.bold,
                              color: read ? Colors.grey.shade700 : Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!read) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade700,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Disaster Map
  Widget _buildDisasterMapWidget(firebase_auth.User? user) {
    if (user == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // More responsive map height calculation
        final screenWidth = constraints.maxWidth;
        double mapHeight;
        
        if (screenWidth > 600) {
          // Tablet
          mapHeight = 220.0;
        } else if (screenWidth > 400) {
          // Large phones (iPhone 14 Pro Max, etc)
          mapHeight = 180.0;
        } else {
          // Small phones (iPhone SE, etc)
          mapHeight = 160.0;
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.map,
                    color: Colors.red.shade700,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  '災害マップ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (kIsWeb) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Web版',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: mapHeight,
                child: PlatformMap(position: _currentPosition),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEmergencyReportDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.warning_rounded,
                            color: Colors.red.shade600,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '緊急報告',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '緊急事態を報告する',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '報告内容を選択してください:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Emergency options
                    _buildEmergencyOption(
                      context,
                      icon: Icons.local_fire_department,
                      title: '火災',
                      subtitle: '火災を発見しました',
                      color: Colors.red,
                    ),
                    _buildEmergencyOption(
                      context,
                      icon: Icons.flood,
                      title: '洪水',
                      subtitle: '洪水が発生しています',
                      color: Colors.blue,
                    ),
                    _buildEmergencyOption(
                      context,
                      icon: Icons.terrain,
                      title: '地震',
                      subtitle: '地震が発生しました',
                      color: Colors.orange,
                    ),
                    _buildEmergencyOption(
                      context,
                      icon: Icons.medical_services,
                      title: '医療緊急事態',
                      subtitle: '医療支援が必要です',
                      color: Colors.green,
                    ),
                    _buildEmergencyOption(
                      context,
                      icon: Icons.warning,
                      title: 'その他の緊急事態',
                      subtitle: 'その他の緊急事態',
                      color: Colors.purple,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          _showEmergencyReportInputDialog(context, title, color, icon);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEmergencyReportInputDialog(
    BuildContext context,
    String type,
    Color color,
    IconData icon,
  ) async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String selectedPriority = 'high';

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text('$type報告', style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '詳細を入力してください',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: descriptionController,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: '例: ○○町で火災が発生しています。煙が見えます。',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.all(12),
                    helperText: '最低10文字、最大500文字',
                    helperStyle: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                    errorStyle: const TextStyle(
                      fontSize: 11,
                      height: 0.8,
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '⚠️ 状況の詳細を入力してください';
                    }
                    if (value.trim().length < 10) {
                      return '⚠️ 少なくとも10文字以上入力してください (現在: ${value.trim().length}文字)';
                    }
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                // const SizedBox(height: 12),
                
                // // Tips section
                // Container(
                //   padding: const EdgeInsets.all(10),
                //   decoration: BoxDecoration(
                //     color: Colors.blue.shade50,
                //     borderRadius: BorderRadius.circular(8),
                //     border: Border.all(color: Colors.blue.shade200),
                //   ),
                //   child: Row(
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: [
                //       Icon(
                //         Icons.lightbulb_outline,
                //         color: Colors.blue.shade700,
                //         size: 16,
                //       ),
                //       const SizedBox(width: 8),
                //       Expanded(
                //         child: Column(
                //           crossAxisAlignment: CrossAxisAlignment.start,
                //           children: [
                //             Text(
                //               '記入のヒント:',
                //               style: TextStyle(
                //                 fontSize: 11,
                //                 fontWeight: FontWeight.bold,
                //                 color: Colors.blue.shade900,
                //               ),
                //             ),
                //             const SizedBox(height: 4),
                //             Text(
                //               '• 場所を具体的に記述\n'
                //               '• 現在の状況を説明\n'
                //               '• 必要な支援を明記',
                //               style: TextStyle(
                //                 fontSize: 10,
                //                 color: Colors.blue.shade800,
                //                 height: 1.4,
                //               ),
                //             ),
                //           ],
                //         ),
                //       ),
                //     ],
                //   ),
                // ),
                const SizedBox(height: 12),
                
                const Text(
                  '優先度',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedPriority,
                  items: const [
                    DropdownMenuItem(
                      value: 'high',
                      child: Row(
                        children: [
                          Icon(Icons.priority_high, color: Colors.red, size: 16),
                          SizedBox(width: 8),
                          Text('🔴 緊急'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'normal',
                      child: Row(
                        children: [
                          Icon(Icons.remove, color: Colors.orange, size: 16),
                          SizedBox(width: 8),
                          Text('🟡 通常'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'low',
                      child: Row(
                        children: [
                          Icon(Icons.arrow_downward, color: Colors.green, size: 16),
                          SizedBox(width: 8),
                          Text('🟢 低'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    selectedPriority = value ?? 'high';
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              } else {
                
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.send, size: 16),
                SizedBox(width: 6),
                Text('報告する'),
              ],
            ),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      final description = descriptionController.text.trim();
      
      try {
        // Get current location
        Position? position;
        try {
          position = await Geolocator.getCurrentPosition();
        } catch (e) {
          print('位置情報取得エラー: $e');
        }

        final reportData = {
          'userId': user.uid,
          'userName': user.displayName ?? 'Unknown User',
          'userEmail': user.email ?? '',
          'type': type,
          'description': description,
          'priority': selectedPriority,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'location': position != null
              ? {
                  'latitude': position.latitude,
                  'longitude': position.longitude,
                }
              : null,
        };

        // 1. Save to emergency_reports collection
        final reportDoc = await FirebaseFirestore.instance
            .collection('emergency_reports')
            .add(reportData);

        // 2. Create notification for the user
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': user.uid,
          'title': '$type報告を送信しました',
          'body': description,
          'type': 'report',
          'reportId': reportDoc.id,
          'reportType': type,
          'priority': selectedPriority,
          'status': 'pending',
          'read': false,
          'pinned': false,
          'favorite': false,
          'receivedAt': FieldValue.serverTimestamp(),
          'location': position != null
              ? {
                  'latitude': position.latitude,
                  'longitude': position.longitude,
                }
              : null,
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$type報告を送信しました',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '管理者に通知されました',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: color,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              action: SnackBarAction(
                label: '確認',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationListScreen(),
                    ),
                  );
                },
              ),
            ),
          );
        }
      } catch (e) {
        print('Error submitting report: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '報告の送信に失敗しました',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          e.toString(),
                          style: const TextStyle(fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red.shade600,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    }
  }

  Widget _buildCompactEmergencyFAB(BuildContext context) {
    return ScaleTransition(
      scale: _fabAnimation,
      child: FloatingActionButton(
        onPressed: () => _showEmergencyReportDialog(context),
        backgroundColor: Colors.red.shade600,
        child: const Icon(Icons.warning_rounded, color: Colors.white),
      ),
    );
  }

  // Drawer 
  Widget _buildDrawer(BuildContext context, firebase_auth.User? user) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          FutureBuilder<String?>(
            future: user != null ? _fetchUsername(user.uid) : null,
            builder: (context, snapshot) {
              final userName = snapshot.data ?? user?.displayName ?? user?.email?.split('@')[0] ?? 'ユーザー';
              final userEmail = user?.email ?? '';
              
              return UserAccountsDrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                currentAccountPicture: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(
                      _getInitials(userName),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ),
                accountName: Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                accountEmail: Text(userEmail),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('設定'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          // Notifications
          if (user != null)
            StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('notifications')
                  .where('userId', isEqualTo: user.uid)
                  .where('read', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                final unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                
                return ListTile(
                  leading: Stack(
                    children: [
                      const Icon(Icons.notifications),
                      if (unreadCount > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(0),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              unreadCount > 9 ? '9+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: const Text('通知'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const NotificationScreen()),
                    );
                  },
                );
              },
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.black),
            title: const Text('ログアウト', style: TextStyle(color: Colors.black)),
            onTap: () async {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
    );
  }

  // Emergency Quick Actions
  Widget _buildEmergencyQuickActions(BuildContext context, firebase_auth.User? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.warning_rounded,
                color: Colors.red.shade700,
                size: 14,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              '緊急報告',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            
            if (screenWidth > 500) {
              // Grid layout for tablets - 5 buttons in a row
              return GridView.count(
                crossAxisCount: 5,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.95, // Increased from 0.9
                children: _buildEmergencyItems(context),
              );
            } else {
              // Grid layout for mobile - 5 buttons in a row
              return GridView.count(
                crossAxisCount: 5,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 6,
                childAspectRatio: 0.9, // Increased from 0.85
                children: _buildEmergencyItems(context),
              );
            }
          },
        ),
      ],
    );
  }

    // NEW: Build emergency items list
    List<Widget> _buildEmergencyItems(BuildContext context) {
      return [
        _buildCompactEmergencyCard(
          context,
          icon: Icons.local_fire_department,
          label: '火災',
          color: Colors.red,
        ),
        _buildCompactEmergencyCard(
          context,
          icon: Icons.flood,
          label: '洪水',
          color: Colors.blue,
        ),
        _buildCompactEmergencyCard(
          context,
          icon: Icons.terrain,
          label: '地震',
          color: Colors.orange,
        ),
        _buildCompactEmergencyCard(
          context,
          icon: Icons.medical_services,
          label: '医療',
          color: Colors.green,
        ),
        _buildCompactEmergencyCard(
          context,
          icon: Icons.warning,
          label: 'その他',
          color: Colors.purple,
        ),
      ];
    }

  // Emergency Card 
  Widget _buildCompactEmergencyCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () {
          _showEmergencyReportInputDialog(context, label, color, icon);
        },
        borderRadius: BorderRadius.circular(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: EdgeInsets.all(constraints.maxWidth * 0.08),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    flex: 3,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    flex: 1,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}