import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../widgets/bottom_nav_bar.dart';
import '../mixins/navigation_mixin.dart';
import 'package:flutter/rendering.dart';

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

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today\'s Nutrition',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
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
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(1)}$unit',
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildWorkoutCard() {
    final workouts = dashboardData['workouts'] ?? {};
    final details = workouts['details'] ?? [];
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today\'s Workouts',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildWorkoutStat('Workouts', workouts['count'] ?? 0),
                _buildWorkoutStat('Duration', '${workouts['total_duration'] ?? 0}m'),
                _buildWorkoutStat('Exercises', workouts['total_exercises'] ?? 0),
              ],
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              ...details.map((workout) {
                final exercises = workout['exercises'] ?? [];
                String setsInfo = '';
                if (exercises.isNotEmpty) {
                  setsInfo = exercises.map((exercise) {
                    final logs = exercise['logs'] ?? [];
                    return logs.map((log) => 
                      '${log['weight']}×${log['reps']}'
                    ).join(' | ');
                  }).join('\n');
                }
                
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
                            fontSize: 16,
                          ),
                        ),
                        Text('${workout['duration']}m'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...exercises.map((exercise) {
                      final logs = exercise['logs'] ?? [];
                      final setsInfo = logs.map((log) => 
                        '${log['weight']}×${log['reps']}'
                      ).join(' | ');
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exercise['name'],
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            setsInfo,
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      );
                    }).toList(),
                    if (details.last != workout) const Divider(),
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
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildWeeklyProgressChart() {
    final weeklyProgress = dashboardData['weekly_progress'] ?? [];
    if (weeklyProgress.isEmpty) return const SizedBox.shrink();

    // Sort by date and take last 7 days
    weeklyProgress.sort((a, b) => 
      DateTime.parse(a['date'].toString()).compareTo(DateTime.parse(b['date'].toString())));
    final recentData = weeklyProgress.length > 7 
        ? weeklyProgress.sublist(weeklyProgress.length - 7) 
        : weeklyProgress;

    // Create data points for weight only
    final List<FlSpot> spots = [];
    final List<String> labels = [];

    // Process data points
    for (var i = 0; i < recentData.length; i++) {
      final entry = recentData[i];
      final goals = entry['goals'] ?? {};
      final date = DateTime.parse(entry['date'].toString());
      
      // Add weight data point
      final weight = (goals['weight']?['current'] ?? 0.0).toDouble();
      if (weight > 0) {
        spots.add(FlSpot(i.toDouble(), weight));
        labels.add(DateFormat('E').format(date));
      }
    }

    if (spots.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weight Progress',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
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
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= labels.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(labels[index]);
                        },
                      ),
                    ),
                  ),
                  minX: 0,
                  maxX: (spots.length - 1).toDouble(),
                  minY: spots.map((e) => e.y).reduce((a, b) => a < b ? a : b) - 5,
                  maxY: spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) + 5,
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false,
                      color: Colors.blue,
                      barWidth: 2,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((spot) {
                          final date = DateTime.parse(recentData[spot.x.toInt()]['date'].toString());
                          return LineTooltipItem(
                            '${DateFormat('MMM d').format(date)}\n${spot.y.toStringAsFixed(1)} lbs',
                            const TextStyle(color: Colors.white),
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
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Goals',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...goals.map((goal) {
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
                case 'steps':
                  unit = '';
                  break;
              }

              // Handle weight goal differently
              if (goal['type'] == 'weight') {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(goal['type']),
                        Text('${goal['current'].toStringAsFixed(1)}/${goal['target'].toStringAsFixed(1)}$unit'),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              }

              // Handle other goals with progress bars
              final progress = goal['progress'] as double;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(goal['type']),
                      Text('${goal['current'].toStringAsFixed(1)}/${goal['target'].toStringAsFixed(1)}$unit'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
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

  Future<void> _logout(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);  // Required by AutomaticKeepAliveClientMixin
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchDashboardData,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNutritionCard(),
                    _buildWorkoutCard(),
                    _buildDailyGoals(),
                    _buildWeeklyProgressChart(),
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
}
