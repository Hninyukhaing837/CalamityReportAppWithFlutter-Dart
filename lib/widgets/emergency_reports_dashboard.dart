import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class EmergencyReportsDashboard extends StatelessWidget {
  final String userId;
  final bool isCompact;

  const EmergencyReportsDashboard({
    super.key,
    required this.userId,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('emergency_reports')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorCard();
        }

        if (!snapshot.hasData) {
          return _buildLoadingCard();
        }

        final reports = snapshot.data!.docs;
        final stats = _calculateStatistics(reports);

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
                    Icons.analytics,
                    color: Colors.blue.shade700,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  '統計情報',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            if (isCompact)
              _buildCompactDashboard(stats)
            else
              _buildFullDashboard(stats, reports),
          ],
        );
      },
    );
  }

  Widget _buildCompactDashboard(Map<String, dynamic> stats) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              Icons.report,
              '今日',
              stats['todayCount'].toString(),
              Colors.blue,
              trend: stats['todayTrend'],
            ),
            Container(width: 1, height: 30, color: Colors.grey.shade300),
            _buildStatItem(
              Icons.pending,
              '未解決',
              stats['pendingCount'].toString(),
              Colors.orange,
            ),
            Container(width: 1, height: 30, color: Colors.grey.shade300),
            _buildStatItem(
              Icons.check_circle,
              '完了',
              stats['resolvedCount'].toString(),
              Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullDashboard(Map<String, dynamic> stats, List<DocumentSnapshot> reports) {
    return Column(
      children: [
        // Stats Grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.2,
          children: [
            _buildModernStatCard(
              icon: Icons.today,
              label: '今日のレポート',
              value: stats['todayCount'].toString(),
              color: Colors.blue,
              trend: stats['todayTrend'],
              subtitle: '昨日比',
            ),
            _buildModernStatCard(
              icon: Icons.pending_actions,
              label: '未解決',
              value: stats['pendingCount'].toString(),
              color: Colors.orange,
              percentage: stats['pendingPercentage'],
              subtitle: '全体の',
            ),
            _buildModernStatCard(
              icon: Icons.check_circle_outline,
              label: '完了',
              value: stats['resolvedCount'].toString(),
              color: Colors.green,
              percentage: stats['resolvedPercentage'],
              subtitle: '全体の',
            ),
            _buildModernStatCard(
              icon: Icons.warning_amber,
              label: '緊急',
              value: stats['emergencyCount'].toString(),
              color: Colors.red,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Weekly Chart
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up, size: 14, color: Colors.blue.shade700),
                    const SizedBox(width: 6),
                    const Text(
                      '週間レポート',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: _buildWeeklyChart(reports),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Type Distribution
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.pie_chart, size: 14, color: Colors.purple.shade700),
                    const SizedBox(width: 6),
                    const Text(
                      'タイプ別分布',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: _buildTypeDistribution(stats),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String label,
    String value,
    Color color, {
    int? trend,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (trend != null && trend != 0) ...[
              const SizedBox(width: 4),
              Icon(
                trend > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: trend > 0 ? Colors.green : Colors.red,
              ),
            ],
          ],
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildModernStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    int? trend,
    int? percentage,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              if (trend != null && trend != 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: trend > 0 
                        ? Colors.green.shade50 
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trend > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 8,
                        color: trend > 0 ? Colors.green : Colors.red,
                      ),
                      Text(
                        '${trend.abs()}',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: trend > 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              if (percentage != null)
                Text(
                  '$percentage%',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1.0,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(List<DocumentSnapshot> reports) {
    final weekData = _getWeeklyData(reports);
    final maxY = weekData.reduce((a, b) => a > b ? a : b).toDouble();
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY > 0 ? maxY + 1 : 5,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const days = ['月', '火', '水', '木', '金', '土', '日'];
                if (value.toInt() >= 0 && value.toInt() < days.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      days[value.toInt()],
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min) {
                  return const SizedBox();
                }
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.grey.shade600,
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: weekData.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.toDouble(),
                color: Colors.blue.shade400,
                width: 12,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTypeDistribution(Map<String, dynamic> stats) {
    final types = [
      {'label': '火災', 'count': stats['fireCount'], 'color': Colors.red},
      {'label': '洪水', 'count': stats['floodCount'], 'color': Colors.blue},
      {'label': '地震', 'count': stats['earthquakeCount'], 'color': Colors.orange},
      {'label': '医療', 'count': stats['medicalCount'], 'color': Colors.green},
      {'label': 'その他', 'count': stats['otherCount'], 'color': Colors.purple},
    ];

    final total = types.fold<int>(0, (sum, item) => sum + (item['count'] as int));

    if (total == 0) {
      return Center(
        child: Text(
          'データなし',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: types.map((type) {
              final count = type['count'] as int;
              if (count == 0) return const SizedBox.shrink();
              
              final percentage = ((count / total) * 100).round();
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: type['color'] as Color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        type['label'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    Text(
                      '$count ($percentage%)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 80,
            child: PieChart(
              PieChartData(
                sections: types
                    .where((type) => (type['count'] as int) > 0)
                    .map((type) {
                  final count = type['count'] as int;
                  final percentage = ((count / total) * 100).round();
                  return PieChartSectionData(
                    value: count.toDouble(),
                    title: '$percentage%',
                    color: type['color'] as Color,
                    radius: 30,
                    titleStyle: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _calculateStatistics(List<DocumentSnapshot> reports) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    int todayCount = 0;
    int yesterdayCount = 0;
    int pendingCount = 0;
    int resolvedCount = 0;
    int emergencyCount = 0;
    
    int fireCount = 0;
    int floodCount = 0;
    int earthquakeCount = 0;
    int medicalCount = 0;
    int otherCount = 0;

    for (var doc in reports) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = (data['createdAt'] as Timestamp?)?.toDate();
      final status = data['status'] ?? 'pending';
      final priority = data['priority'] ?? 'normal';
      final type = data['type'] ?? 'その他';

      if (timestamp != null) {
        if (timestamp.isAfter(todayStart)) {
          todayCount++;
        } else if (timestamp.isAfter(yesterdayStart)) {
          yesterdayCount++;
        }
      }

      if (status == 'pending') pendingCount++;
      if (status == 'resolved') resolvedCount++;
      if (priority == 'high') emergencyCount++;

      switch (type) {
        case '火災':
          fireCount++;
          break;
        case '洪水':
          floodCount++;
          break;
        case '地震':
          earthquakeCount++;
          break;
        case '医療':
          medicalCount++;
          break;
        default:
          otherCount++;
      }
    }

    final totalCount = reports.length;
    final pendingPercentage = totalCount > 0 
        ? ((pendingCount / totalCount) * 100).round()
        : 0;
    final resolvedPercentage = totalCount > 0
        ? ((resolvedCount / totalCount) * 100).round()
        : 0;

    return {
      'todayCount': todayCount,
      'yesterdayCount': yesterdayCount,
      'todayTrend': todayCount - yesterdayCount,
      'pendingCount': pendingCount,
      'resolvedCount': resolvedCount,
      'emergencyCount': emergencyCount,
      'totalCount': totalCount,
      'pendingPercentage': pendingPercentage,
      'resolvedPercentage': resolvedPercentage,
      'fireCount': fireCount,
      'floodCount': floodCount,
      'earthquakeCount': earthquakeCount,
      'medicalCount': medicalCount,
      'otherCount': otherCount,
    };
  }

  List<int> _getWeeklyData(List<DocumentSnapshot> reports) {
    final now = DateTime.now();
    final weekData = List<int>.filled(7, 0);

    for (var doc in reports) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = (data['createdAt'] as Timestamp?)?.toDate();

      if (timestamp != null) {
        final daysDiff = now.difference(timestamp).inDays;
        if (daysDiff < 7) {
          final index = 6 - daysDiff;
          if (index >= 0 && index < 7) {
            weekData[index]++;
          }
        }
      }
    }

    return weekData;
  }

  Widget _buildLoadingCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
}