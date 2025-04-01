import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:ui';
import '../widgets/bottom_nav_bar.dart';
import '../mixins/navigation_mixin.dart';
import 'package:flutter/rendering.dart';
import '../widgets/user_profile_menu.dart';

// iOS-style constants
const kBackgroundColor = Color(0xFFF2F2F7);
const kCardBackground = Colors.white;
const kPrimaryBlue = Color(0xFF007AFF);
const kSecondaryText = Color(0xFF8E8E93);
const kBorderRadius = 16.0;
const kSpacing = 16.0;

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> 
    with NavigationMixin, WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  Map<String, dynamic> dashboardData = {};
  bool isLoading = true;
  bool _isVisible = true;
  String? username;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchUserData();
    _fetchDashboardData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isVisible) {
      _fetchDashboardData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      bool isVisible = route.isCurrent;
      if (_isVisible != isVisible) {
        _isVisible = isVisible;
        if (_isVisible) {
          _fetchDashboardData();
        }
      }
    }
  }

  Future<void> _fetchUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse('http://localhost:8000/users/me'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          username = data['name'];
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  Future<void> _fetchDashboardData() async {
    if (!mounted) return;
    
    setState(() => isLoading = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/users/dashboard'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          dashboardData = json.decode(response.body);
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load dashboard data');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() => isLoading = false);
    }
  }

  Widget _buildNutritionCard() {
    final nutrition = dashboardData['nutrition'] ?? {};
    
    return _buildCard(
      child: Padding(
        padding: const EdgeInsets.all(kSpacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Today\'s Nutrition'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNutritionItem('Calories', nutrition['calories'] ?? 0, 'kcal'),
                _buildNutritionItem('Protein', nutrition['protein'] ?? 0, 'g'),
                _buildNutritionItem('Carbs', nutrition['carbs'] ?? 0, 'g'),
                _buildNutritionItem('Fats', nutrition['fats'] ?? 0, 'g'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionItem(String label, double value, String unit) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: kSecondaryText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(1)}$unit',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkoutCard() {
    final workouts = dashboardData['workouts'] ?? {};
    final details = workouts['details'] ?? [];
    
    return _buildCard(
      child: Padding(
        padding: const EdgeInsets.all(kSpacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Today\'s Workouts'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildWorkoutStat('Workouts', workouts['count'] ?? 0),
                _buildWorkoutStat('Duration', '${workouts['total_duration'] ?? 0}m'),
                _buildWorkoutStat('Exercises', workouts['total_exercises'] ?? 0),
              ],
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: kSpacing),
              Container(
                height: 1,
                color: kBackgroundColor,
              ),
              const SizedBox(height: kSpacing),
              ...details.map((workout) {
                final exercises = workout['exercises'] ?? [];
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          workout['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: Colors.black,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: kBackgroundColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${workout['duration']}m',
                            style: const TextStyle(
                              color: kSecondaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: kSpacing / 2),
                    ...exercises.map((exercise) {
                      final logs = exercise['logs'] ?? [];
                      final setsInfo = logs.map((log) => 
                        '${log['weight']}×${log['reps']}'
                      ).join(' | ');
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: kSpacing / 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exercise['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              setsInfo,
                              style: TextStyle(
                                color: kSecondaryText,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    if (details.last != workout) ...[
                      const SizedBox(height: kSpacing / 2),
                      Container(
                        height: 1,
                        color: kBackgroundColor,
                      ),
                      const SizedBox(height: kSpacing / 2),
                    ],
                  ],
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutStat(String label, dynamic value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: kSecondaryText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyProgressChart() {
    final weeklyProgress = dashboardData['weekly_progress'] ?? [];
    if (weeklyProgress.isEmpty) return const SizedBox.shrink();

    // Sort data by date
    weeklyProgress.sort((a, b) => 
      DateTime.parse(a['date'].toString()).compareTo(DateTime.parse(b['date'].toString())));
    
    // Get the last 7 days of data
    final recentData = weeklyProgress.length > 7 
        ? weeklyProgress.sublist(weeklyProgress.length - 7) 
        : weeklyProgress;

    final List<FlSpot> spots = [];
    final List<String> labels = [];
    double minWeight = double.infinity;
    double maxWeight = double.negativeInfinity;

    // Create a map to store unique date entries
    final Map<String, int> dateIndices = {};
    int currentIndex = 0;

    for (var entry in recentData) {
      final goals = entry['goals'] ?? {};
      final date = DateTime.parse(entry['date'].toString());
      final weight = (goals['weight']?['current'] ?? 0.0).toDouble();
      final dateStr = DateFormat('MM/dd').format(date);
      
      // Only add data points for days that have weight data
      if (weight > 0 && !dateIndices.containsKey(dateStr)) {
        dateIndices[dateStr] = currentIndex;
        spots.add(FlSpot(currentIndex.toDouble(), weight));
        labels.add(dateStr);
        
        // Update min and max weights
        minWeight = minWeight > weight ? weight : minWeight;
        maxWeight = maxWeight < weight ? weight : maxWeight;
        
        currentIndex++;
      }
    }

    if (spots.isEmpty) return const SizedBox.shrink();

    // Calculate Y-axis range with padding
    final weightRange = maxWeight - minWeight;
    final yPadding = weightRange * 0.1; // 10% padding
    
    // Round minY down to nearest 0.5 and maxY up to nearest 0.5
    final minY = (minWeight - yPadding - 0.5).floorToDouble();
    final maxY = (maxWeight + yPadding + 0.5).ceilToDouble();
    
    // Calculate a nice interval (0.5 or 1.0 depending on the range)
    final interval = (maxY - minY) <= 5 ? 0.5 : 1.0;

    return _buildCard(
      child: Padding(
        padding: const EdgeInsets.all(kSpacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Weight Progress'),
            const SizedBox(height: kSpacing / 2),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: kBackgroundColor,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: interval,
                        getTitlesWidget: (value, meta) {
                          // Only show if it's a multiple of our interval
                          if ((value % interval).abs() > 0.01) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            value.toStringAsFixed(1),
                            style: const TextStyle(
                              color: kSecondaryText,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 1, // Show every label
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= labels.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              labels[index],
                              style: const TextStyle(
                                color: kSecondaryText,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  minX: 0,
                  maxX: (spots.length - 1).toDouble(),
                  minY: minY,
                  maxY: maxY,
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: kPrimaryBlue,
                      barWidth: 2,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.white,
                            strokeWidth: 2,
                            strokeColor: kPrimaryBlue,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: kPrimaryBlue.withOpacity(0.1),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: Colors.black.withOpacity(0.8),
                      tooltipRoundedRadius: 8,
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((spot) {
                          final index = spot.x.toInt();
                          return LineTooltipItem(
                            '${labels[index]}\n${spot.y.toStringAsFixed(1)} kg',
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyGoals() {
    final goals = dashboardData['goals']?['daily'] ?? [];
    
    // Filter out weightlifting goals but keep weight and nutrient goals
    final dailyGoals = goals.where((goal) {
      final type = goal['type'] as String;
      return type == 'calories' || type == 'protein' || type == 'carbs' || type == 'fats' || type == 'weight';
    }).toList();

    // Sort goals: weight first, then others alphabetically
    dailyGoals.sort((a, b) {
      if (a['type'] == 'weight') return -1;
      if (b['type'] == 'weight') return 1;
      return (a['type'] as String).compareTo(b['type'] as String);
    });
    
    return _buildCard(
      child: Padding(
        padding: const EdgeInsets.all(kSpacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Daily Goals'),
            ...dailyGoals.map((goal) {
              String unit = '';
              switch(goal['type']) {
                case 'weight':
                  unit = ' lbs';
                  break;
                case 'protein':
                case 'carbs':
                case 'fats':
                  unit = 'g';
                  break;
                case 'calories':
                  unit = ' kcal';
                  break;
              }

              // Handle weight goals differently (no progress bar)
              if (goal['type'] == 'weight') {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        goal['type'],
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        '${goal['current'].toStringAsFixed(1)}->${goal['target'].toStringAsFixed(1)}$unit',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: kPrimaryBlue,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Handle nutrient goals with progress bars
              final progress = goal['progress'] as double;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          goal['type'],
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          '${goal['current'].toStringAsFixed(1)}/${goal['target'].toStringAsFixed(1)}$unit',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: kPrimaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: kBackgroundColor,
                      valueColor: const AlwaysStoppedAnimation<Color>(kPrimaryBlue),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);  // Required by AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        elevation: 0,
        title: const Text(
          "Dashboard",
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (username != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: UserProfileMenu(username: username!),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryBlue))
          : RefreshIndicator(
              color: kPrimaryBlue,
              backgroundColor: kCardBackground,
              onRefresh: _fetchDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNutritionCard(),
                    _buildWorkoutCard(),
                    _buildDailyGoals(),
                    _buildWeeklyProgressChart(),
                    const SizedBox(height: kSpacing), // Bottom padding
                  ],
                ),
              ),
            ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: getCurrentIndex(context),
        onTap: (index) => handleNavigation(index, context),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: kSpacing,
        vertical: kSpacing / 2,
      ),
      decoration: BoxDecoration(
        color: kCardBackground,
        borderRadius: BorderRadius.circular(kBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kBorderRadius),
        child: child,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpacing),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }
}
