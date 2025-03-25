import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/bottom_nav_bar.dart';
import '../mixins/navigation_mixin.dart';

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

  Widget _buildGoalCard(Map<String, dynamic> goal) {
    final isDaily = _dailyGoals.contains(goal['category'].toString().toLowerCase());
    final isWeightlifting = goal['goal_type'] == 'weightlifting';
    final isWeight = goal['category'] == 'weight';
    
    // Calculate progress only for non-weight goals
    double progress = isWeight ? 0.0 : (goal['current_value'] / goal['target_value']).clamp(0.0, 1.0);
    bool isCompleted = isWeight ? false : progress >= 1.0;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isDaily) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.refresh,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ],
                        ],
                      ),
                      if (isWeightlifting)
                        Text(
                          'Weightlifting PR Goal',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      if (isDaily)
                        Text(
                          'Daily Goal',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Completed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteGoal(goal['id']);
                    } else if (value == 'update') {
                      _showUpdateProgressDialog(goal);
                    } else if (value == 'edit') {
                      _editGoal(goal);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'update',
                      child: Text('Update Progress'),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit Goal'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(goal['description']),
            if (!isWeight) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isWeight)
                  Text(
                    'Current: ${goal['current_value']} kg / Target: ${goal['target_value']} kg',
                  )
                else
                  Text(
                    '${goal['current_value']} ${_getUnitForCategory(goal['category'])} / ${goal['target_value']} ${_getUnitForCategory(goal['category'])}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : goals.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'No goals yet',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async {
                          final result = await Navigator.pushNamed(context, '/create-goal');
                          if (result == true) {
                            _fetchGoals();
                          }
                        },
                        child: const Text('Create Your First Goal'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchGoals,
                  child: ListView.builder(
                    itemCount: goals.length,
                    itemBuilder: (context, index) => _buildGoalCard(goals[index]),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/create-goal');
          if (result == true) {
            _fetchGoals();
          }
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: getCurrentIndex(context),
        onTap: (index) => handleNavigation(index, context),
      ),
    );
  }
} 