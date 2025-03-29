import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/bottom_nav_bar.dart';
import '../mixins/navigation_mixin.dart';
import '../constants/colors.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> with NavigationMixin {
  List<Map<String, dynamic>> goals = [];
  bool isLoading = true;

  // Define which categories are daily goals
  final Set<String> _dailyGoals = {'calories', 'steps', 'protein', 'carbs', 'fats', 'weight'};

  @override
  void initState() {
    super.initState();
    _fetchGoals();
  }

  Future<void> _fetchGoals() async {
    setState(() => isLoading = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/users/goals'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          goals = data.map((goal) {
            final goalType = goal['goal_type'] as String;
            final isWeightlifting = goalType.startsWith('weightlifting:');
            final exerciseName = isWeightlifting ? 
                goalType.split(':')[1] : null;
            final baseGoalType = isWeightlifting ? 'weightlifting' : goalType;
            final isDaily = _dailyGoals.contains(baseGoalType.toLowerCase());

            // For daily goals, set deadline to end of current day
            final now = DateTime.now();
            final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
            final deadline = isDaily ? endOfDay.toIso8601String().split('T')[0] : 
                (goal['target_date'] ?? DateTime.now().add(const Duration(days: 30)).toIso8601String().split('T')[0]);

            return {
              'id': goal['id'],
              'title': exerciseName ?? goalType,
              'description': _getGoalDescription(goal),
              'target_value': goal['target_value'],
              'current_value': goal['current_value'] ?? 0.0,
              'category': baseGoalType,
              'goal_type': baseGoalType,
              'deadline': deadline,
              'completed': goal['is_completed'] ?? false,
              'exercise_name': exerciseName,
            };
          }).toList();
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load goals');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() => isLoading = false);
    }
  }

  String _getGoalDescription(Map<String, dynamic> goal) {
    final goalType = goal['goal_type'] as String;
    final isWeightlifting = goalType.startsWith('weightlifting:');
    final baseGoalType = isWeightlifting ? 'weightlifting' : goalType;

    if (isWeightlifting) {
      return 'Target PR: ${goal['target_value']} ${_getUnitForCategory('weightlifting')}';
    }
    return 'Target: ${goal['target_value']} ${_getUnitForCategory(baseGoalType)}';
  }

  String _getGoalTitle(Map<String, dynamic> goal) {
    if (goal['goal_type'] == 'weightlifting') {
      return goal['exercise_name'] ?? 'Unknown Exercise';
    }
    return goal['goal_type'].toString().toUpperCase();
  }

  Future<void> _deleteGoal(int goalId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    try {
      final response = await http.delete(
        Uri.parse('http://localhost:8000/users/goals/$goalId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          goals.removeWhere((goal) => goal['id'] == goalId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal deleted successfully')),
        );
      } else {
        throw Exception('Failed to delete goal');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _updateGoalProgress(int goalId, double newValue) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    try {
      final response = await http.put(
        Uri.parse('http://localhost:8000/users/goals/$goalId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'current_value': newValue}),
      );

      if (response.statusCode == 200) {
        _fetchGoals();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Progress updated successfully')),
        );
      } else {
        throw Exception('Failed to update progress');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _editGoal(Map<String, dynamic> goal) async {
    final targetController = TextEditingController(text: goal['target_value'].toString());
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${goal['title']} Goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: targetController,
              decoration: InputDecoration(
                labelText: 'New Target Value',
                suffixText: _getUnitForCategory(goal['category']),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a target value';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (targetController.text.isEmpty) return;
              
              SharedPreferences prefs = await SharedPreferences.getInstance();
              String token = prefs.getString('token') ?? '';

              try {
                final response = await http.put(
                  Uri.parse('http://localhost:8000/users/goals/${goal['id']}'),
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Content-Type': 'application/json',
                  },
                  body: json.encode({
                    'target_value': double.parse(targetController.text),
                  }),
                );

                if (response.statusCode == 200) {
                  Navigator.pop(context);
                  _fetchGoals();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Goal updated successfully')),
                  );
                } else {
                  throw Exception('Failed to update goal');
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showUpdateProgressDialog(Map<String, dynamic> goal) {
    final TextEditingController controller = TextEditingController(
      text: goal['current_value'].toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Progress'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Current Value',
            hintText: 'Enter current progress',
            suffixText: _getUnitForCategory(goal['category']),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newValue = double.tryParse(controller.text);
              if (newValue != null) {
                _updateGoalProgress(goal['id'], newValue);
                Navigator.pop(context);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  String _getUnitForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'weight':
        return 'kg';
      case 'steps':
        return 'steps';
      case 'calories':
        return 'kcal';
      case 'distance':
        return 'km';
      default:
        return '';
    }
  }

  List<Map<String, dynamic>> _getDailyGoals() {
    final today = DateTime.now();
    final todayStr = today.toIso8601String().split('T')[0];
    
    return goals.where((goal) {
      final baseGoalType = goal['goal_type'].toString().split(':')[0];
      return _dailyGoals.contains(baseGoalType.toLowerCase()) && 
             goal['deadline'] == todayStr;
    }).toList();
  }

  List<Map<String, dynamic>> _getNonDailyGoals() {
    return goals.where((goal) {
      final baseGoalType = goal['goal_type'].toString().split(':')[0];
      return !_dailyGoals.contains(baseGoalType.toLowerCase());
    }).toList()
      ..sort((a, b) => a['deadline'].compareTo(b['deadline']));
  }

  Widget _buildGoalCard(Map<String, dynamic> goal) {
    final isDaily = _dailyGoals.contains(goal['category'].toString().toLowerCase());
    final isWeightlifting = goal['goal_type'] == 'weightlifting';
    final isWeight = goal['category'] == 'weight';
    
    double progress = isWeight ? 0.0 : (goal['current_value'] / goal['target_value']).clamp(0.0, 1.0);
    bool isCompleted = isWeight ? false : progress >= 1.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _getGoalTitle(goal),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          if (isDaily) ...[
                            const SizedBox(width: 8),
                            Icon(
                              CupertinoIcons.refresh,
                              size: 14,
                              color: Colors.grey[400],
                            ),
                          ],
                        ],
                      ),
                      if (isWeightlifting || isDaily)
                        Text(
                          isWeightlifting ? 'Weightlifting PR Goal' : 'Daily Goal',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: kPrimaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Completed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kPrimaryBlue,
                      ),
                    ),
                  ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: Icon(
                    CupertinoIcons.ellipsis,
                    color: Colors.grey[400],
                  ),
                  onPressed: () {
                    showCupertinoModalPopup(
                      context: context,
                      builder: (context) => CupertinoActionSheet(
                        actions: [
                          CupertinoActionSheetAction(
                            child: const Text('Update Progress'),
                            onPressed: () {
                              Navigator.pop(context);
                              _showUpdateProgressDialog(goal);
                            },
                          ),
                          CupertinoActionSheetAction(
                            child: const Text('Edit Goal'),
                            onPressed: () {
                              Navigator.pop(context);
                              _editGoal(goal);
                            },
                          ),
                          CupertinoActionSheetAction(
                            isDestructiveAction: true,
                            child: const Text('Delete'),
                            onPressed: () {
                              Navigator.pop(context);
                              _deleteGoal(goal['id']);
                            },
                          ),
                        ],
                        cancelButton: CupertinoActionSheetAction(
                          child: const Text('Cancel'),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              goal['description'],
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
            if (!isWeight) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(kPrimaryBlue),
                  minHeight: 6,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              isWeight
                ? 'Current: ${goal['current_value']} kg / Target: ${goal['target_value']} kg'
                : '${goal['current_value']} ${_getUnitForCategory(goal['category'])} / ${goal['target_value']} ${_getUnitForCategory(goal['category'])}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalsList() {
    final dailyGoals = _getDailyGoals();
    final nonDailyGoals = _getNonDailyGoals();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: _fetchGoals,
        ),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (dailyGoals.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    'Today\'s Goals',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                ...dailyGoals.map((goal) => _buildGoalCard(goal)),
              ],
              if (nonDailyGoals.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    'Long-term Goals',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                ...nonDailyGoals.map((goal) => _buildGoalCard(goal)),
              ],
              if (dailyGoals.isEmpty && nonDailyGoals.isEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Text(
                        'No goals yet',
                        style: TextStyle(
                          fontSize: 17,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      CupertinoButton(
                        color: kPrimaryBlue,
                        child: const Text('Create Your First Goal'),
                        onPressed: () async {
                          final result = await Navigator.pushNamed(context, '/create-goal');
                          if (result == true) {
                            _fetchGoals();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 80), // Space for FAB
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Goals',
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: isLoading
          ? Center(
              child: CupertinoActivityIndicator(
                radius: 12,
                color: kPrimaryBlue,
              ),
            )
          : _buildGoalsList(),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: kPrimaryBlue.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.pushNamed(context, '/create-goal');
            if (result == true) {
              _fetchGoals();
            }
          },
          backgroundColor: kPrimaryBlue,
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: getCurrentIndex(context),
        onTap: (index) => handleNavigation(index, context),
      ),
    );
  }
} 