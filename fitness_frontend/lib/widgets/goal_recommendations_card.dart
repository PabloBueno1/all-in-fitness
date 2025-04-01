import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/colors.dart';

class GoalRecommendationsCard extends StatefulWidget {
  final Function() onGoalsCreated;

  const GoalRecommendationsCard({
    Key? key,
    required this.onGoalsCreated,
  }) : super(key: key);

  @override
  _GoalRecommendationsCardState createState() => _GoalRecommendationsCardState();
}

class _GoalRecommendationsCardState extends State<GoalRecommendationsCard> {
  Map<String, dynamic>? _recommendations;
  bool _isLoading = false;
  bool _isCreatingGoal = false;
  bool showRecommendations = false;

  Future<void> _getRecommendations() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse('http://localhost:8000/recommendations/goals'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _recommendations = json.decode(response.body);
          showRecommendations = true;
        });
      }
    } catch (e) {
      print('Error fetching recommendations: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createRecommendedGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null || _recommendations == null) return;

      // Get existing goals
      final response = await http.get(
        Uri.parse('http://localhost:8000/users/goals'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) return;

      final existingGoals = json.decode(response.body) as List;
      final goalMap = {
        for (var goal in existingGoals) goal['goal_type']: goal
      };

      // Update or create weight goal
      if (_recommendations!.containsKey('weight_goal') && 
          _recommendations!['weight_goal']['target_weight'] != null) {
        final weightGoal = goalMap['weight'];
        if (weightGoal != null) {
          // Update existing weight goal
          await http.put(
            Uri.parse('http://localhost:8000/users/goals/${weightGoal['id']}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'target_value': _recommendations!['weight_goal']['target_weight'],
              'current_value': _recommendations!['weight_goal']['current_weight'],
              'target_date': DateTime.now().toIso8601String().split('T')[0],  // Daily goal uses today's date
            }),
          );
        } else {
          // Create new weight goal if none exists
          await http.post(
            Uri.parse('http://localhost:8000/users/goals'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'goal_type': 'weight',
              'target_value': _recommendations!['weight_goal']['target_weight'],
              'current_value': _recommendations!['weight_goal']['current_weight'],
              'start_date': DateTime.now().toIso8601String().split('T')[0],
              'target_date': DateTime.now().toIso8601String().split('T')[0],  // Daily goal uses today's date
              'time_frame': 'daily',
            }),
          );
        }
      }

      // Update or create calorie goal
      final calorieGoal = goalMap['calories'];
      if (calorieGoal != null) {
        await http.put(
          Uri.parse('http://localhost:8000/users/goals/${calorieGoal['id']}'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'target_value': _recommendations!['calorie_goal']['daily_target'],
          }),
        );
      } else {
        await http.post(
          Uri.parse('http://localhost:8000/users/goals'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'goal_type': 'calories',
            'target_value': _recommendations!['calorie_goal']['daily_target'],
            'current_value': 0,
            'start_date': DateTime.now().toIso8601String().split('T')[0],
            'target_date': DateTime.now().toIso8601String().split('T')[0],
          }),
        );
      }

      // Update or create macro goals
      final macroGoals = [
        ('protein', _recommendations!['calorie_goal']['protein_target']),
        ('carbs', _recommendations!['calorie_goal']['carb_target']),
        ('fats', _recommendations!['calorie_goal']['fat_target']),
      ];

      for (var (type, target) in macroGoals) {
        final existingGoal = goalMap[type];
        if (existingGoal != null) {
          await http.put(
            Uri.parse('http://localhost:8000/users/goals/${existingGoal['id']}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'target_value': target,
            }),
          );
        } else {
          await http.post(
            Uri.parse('http://localhost:8000/users/goals'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'goal_type': type,
              'target_value': target,
              'current_value': 0,
              'start_date': DateTime.now().toIso8601String().split('T')[0],
              'target_date': DateTime.now().toIso8601String().split('T')[0],
            }),
          );
        }
      }

      widget.onGoalsCreated();
      setState(() => showRecommendations = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goals updated successfully')),
        );
      }
    } catch (e) {
      print('Error updating goals: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update goals')),
        );
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildRecommendationSection(String title, List<Widget> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.systemGrey5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          ...items,
        ],
      ),
    );
  }

  Widget _buildGoalItem(String title, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(icon, color: kPrimaryBlue, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(
              CupertinoIcons.add_circled,
              color: kPrimaryBlue,
              size: 24,
            ),
            onPressed: () => _createSingleGoal(title, value),
          ),
        ],
      ),
    );
  }

  Future<void> _createSingleGoal(String title, String value) async {
    setState(() => _isCreatingGoal = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String token = prefs.getString('token') ?? '';

      // Determine goal type and target value based on the title
      String goalType;
      double targetValue;
      double? currentValue;
      DateTime targetDate = DateTime.now();  // Daily goals use today's date

      if (title == 'weight') {  // Changed from title.contains('Weight') to exact match
        goalType = 'weight';
        // Parse the target and current weight from the value string
        // Format is "Current: X lbs\nTarget: Y lbs"
        final currentWeightStr = value.split('\n')[0].split(': ')[1].split(' ')[0];
        final targetWeightStr = value.split('\n')[1].split(': ')[1].split(' ')[0];
        currentValue = double.parse(currentWeightStr);
        targetValue = double.parse(targetWeightStr);
        targetDate = DateTime.now();  // Weight is a daily goal
      } else if (title.startsWith('weightlifting:')) {
        // For weightlifting goals, the title is already in the correct format
        goalType = title;  // Use the full title as the goal type
        // Parse the target weight from the value string
        // Format is "Current: X lbs\nTarget: Y lbs\nTimeframe: Z\nFrequency: W\nMuscles: V"
        try {
          final lines = value.split('\n');
          final currentWeightStr = lines[0].split(': ')[1].replaceAll(RegExp(r'[^\d.]'), '');
          final targetWeightStr = lines[1].split(': ')[1].replaceAll(RegExp(r'[^\d.]'), '');
          
          currentValue = double.parse(currentWeightStr);
          targetValue = double.parse(targetWeightStr);
          
          // Parse timeframe to set target date
          final timeframeStr = lines[2].split(': ')[1];
          if (timeframeStr.contains('8 weeks')) {
            targetDate = DateTime.now().add(const Duration(days: 56));
          } else if (timeframeStr.contains('12 weeks')) {
            targetDate = DateTime.now().add(const Duration(days: 84));
          } else if (timeframeStr.contains('16 weeks')) {
            targetDate = DateTime.now().add(const Duration(days: 112));
          }
        } catch (e) {
          print('Error parsing weightlifting values: $e');
          print('Value string: $value');
          rethrow;
        }
      } else if (title.contains('Calories')) {
        goalType = 'calories';
        // Parse just the number from the start of the string, removing 'kcal' and any other text
        targetValue = double.parse(value.split(' ')[0].replaceAll(RegExp(r'[^0-9.]'), ''));
      } else if (title.contains('Protein')) {
        goalType = 'protein';
        // Parse just the number from the start of the string, removing 'g' and any other text
        targetValue = double.parse(value.split(' ')[0].replaceAll(RegExp(r'[^0-9.]'), ''));
      } else if (title.contains('Carbs')) {
        goalType = 'carbs';
        // Parse just the number from the start of the string, removing 'g' and any other text
        targetValue = double.parse(value.split(' ')[0].replaceAll(RegExp(r'[^0-9.]'), ''));
      } else if (title.contains('Fats')) {
        goalType = 'fats';
        // Parse just the number from the start of the string, removing 'g' and any other text
        targetValue = double.parse(value.split(' ')[0].replaceAll(RegExp(r'[^0-9.]'), ''));
      } else {
        // Check if this is a weightlifting exercise
        final weightliftingGoals = _recommendations?['weightlifting_goals'] as List?;
        if (weightliftingGoals != null && 
            weightliftingGoals.any((goal) => goal['exercise_name'] == title)) {
          goalType = 'weightlifting:$title';
          try {
            final lines = value.split('\n');
            final currentWeightStr = lines[0].split(': ')[1].replaceAll(RegExp(r'[^\d.]'), '');
            final targetWeightStr = lines[1].split(': ')[1].replaceAll(RegExp(r'[^\d.]'), '');
            
            currentValue = double.parse(currentWeightStr);
            targetValue = double.parse(targetWeightStr);
            
            // Parse timeframe to set target date
            final timeframeStr = lines[2].split(': ')[1];
            if (timeframeStr.contains('8 weeks')) {
              targetDate = DateTime.now().add(const Duration(days: 56));
            } else if (timeframeStr.contains('12 weeks')) {
              targetDate = DateTime.now().add(const Duration(days: 84));
            } else if (timeframeStr.contains('16 weeks')) {
              targetDate = DateTime.now().add(const Duration(days: 112));
            }
          } catch (e) {
            print('Error parsing weightlifting values: $e');
            print('Value string: $value');
            rethrow;
          }
        } else {
          throw Exception('Unknown goal type: $title');
        }
      }

      // First, check if a goal of this type already exists
      final goalsResponse = await http.get(
        Uri.parse('http://localhost:8000/users/goals'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (goalsResponse.statusCode == 200) {
        final existingGoals = json.decode(goalsResponse.body) as List;
        final existingGoal = existingGoals.firstWhere(
          (goal) => goal['goal_type'] == goalType,
          orElse: () => null,
        );

        if (existingGoal != null) {
          // Update existing goal
          final updateResponse = await http.put(
            Uri.parse('http://localhost:8000/users/goals/${existingGoal['id']}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'target_value': targetValue,
              'current_value': currentValue,
              'target_date': targetDate.toIso8601String().split('T')[0],
            }),
          );

          if (updateResponse.statusCode == 200) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Goal updated successfully')),
              );
              widget.onGoalsCreated();
            }
            return;
          }
        }
      }

      // If no existing goal was found or update failed, create a new one
      final createResponse = await http.post(
        Uri.parse('http://localhost:8000/users/goals'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'goal_type': goalType,
          'target_value': targetValue,
          'current_value': currentValue ?? 0.0,
          'start_date': DateTime.now().toIso8601String().split('T')[0],
          'target_date': targetDate.toIso8601String().split('T')[0],
          'time_frame': goalType.startsWith('weightlifting:') ? 'long_term' : 'daily',
        }),
      );

      if (createResponse.statusCode == 200 || createResponse.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Goal created successfully')),
          );
          widget.onGoalsCreated();
        }
      } else {
        throw Exception('Failed to create goal');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingGoal = false);
      }
    }
  }

  String _determineGoalType() {
    if (_recommendations == null || !_recommendations!.containsKey('weight_goal')) {
      return 'Target Weight';
    }

    final currentWeight = _recommendations!['weight_goal']['current_weight'] as num;
    final targetWeight = _recommendations!['weight_goal']['target_weight'] as num;

    if (targetWeight > currentWeight) {
      return 'Bulking Goal';
    } else if (targetWeight < currentWeight) {
      return 'Cutting Goal';
    } else {
      return 'Maintenance Goal';
    }
  }

  // Update calorie recommendations based on goal type
  Widget _buildNutritionSection() {
    if (!_recommendations!.containsKey('calorie_goal')) {
      return const SizedBox.shrink();
    }

    final goalType = _determineGoalType();
    String calorieDescription = '${_recommendations!['calorie_goal']['daily_target']} kcal';
    
    if (goalType == 'Bulking Goal') {
      calorieDescription += '\nCaloric surplus for muscle gain';
    } else if (goalType == 'Cutting Goal') {
      calorieDescription += '\nCaloric deficit for fat loss';
    } else {
      calorieDescription += '\nMaintenance calories';
    }

    return Column(
      children: [
        _buildRecommendationSection(
          'Nutrition Goals',
          [
            _buildGoalItem(
              'Daily Calories',
              calorieDescription,
              CupertinoIcons.flame,
            ),
            if (_recommendations!['calorie_goal'].containsKey('protein_target'))
              _buildGoalItem(
                'Daily Protein',
                '${_recommendations!['calorie_goal']['protein_target']}g',
                CupertinoIcons.chart_pie,
              ),
            if (_recommendations!['calorie_goal'].containsKey('carb_target'))
              _buildGoalItem(
                'Daily Carbs',
                '${_recommendations!['calorie_goal']['carb_target']}g',
                CupertinoIcons.chart_pie,
              ),
            if (_recommendations!['calorie_goal'].containsKey('fat_target'))
              _buildGoalItem(
                'Daily Fats',
                '${_recommendations!['calorie_goal']['fat_target']}g',
                CupertinoIcons.chart_pie,
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildWeightliftingSection() {
    if (!_recommendations!.containsKey('weightlifting_goals')) {
      return const SizedBox.shrink();
    }

    final weightliftingGoals = _recommendations!['weightlifting_goals'] as List;
    if (weightliftingGoals.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        _buildRecommendationSection(
          'Weightlifting Goals',
          weightliftingGoals.map((goal) {
            final currentMax = goal['current_max'];
            final targetWeight = goal['target_weight'];
            final timeframe = goal['timeframe'];
            final frequency = goal['frequency'];
            final muscles = goal['muscles_targeted'];
            final exerciseName = goal['exercise_name'];

            return _buildGoalItem(
              exerciseName,  // Show just the exercise name in the UI
              'Current: ${currentMax}lbs\nTarget: ${targetWeight}lbs\nTimeframe: $timeframe\nFrequency: $frequency\nMuscles: $muscles',
              CupertinoIcons.arrow_up_circle,
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStyledButton({
    required String text,
    required VoidCallback onPressed,
    bool isPrimary = true,
  }) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: isPrimary
          ? const LinearGradient(
              colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
        color: isPrimary ? null : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isPrimary 
              ? const Color(0xFF4A90E2).withOpacity(0.3)
              : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: isPrimary ? Colors.white : const Color(0xFF4A90E2),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!showRecommendations) {
      return Container(
        margin: const EdgeInsets.all(kSpacing),
        child: _buildStyledButton(
          text: 'Get Goal Recommendations',
          onPressed: _getRecommendations,
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_recommendations == null) {
      return const SizedBox.shrink();
    }

    // Print the recommendations to debug
    print('Recommendations: $_recommendations');

    return Container(
      margin: const EdgeInsets.all(kSpacing),
      padding: const EdgeInsets.all(kSpacing),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recommended Goals',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  setState(() => showRecommendations = false);
                },
                child: const Icon(CupertinoIcons.xmark),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Weight Goals Section
          if (_recommendations!.containsKey('weight_goal'))
            Column(
              children: [
                _buildRecommendationSection(
                  'Weight Goals',
                  [
                    _buildGoalItem(
                      'weight',  // Changed from _determineGoalType() to just 'weight'
                      'Current: ${_recommendations!['weight_goal']['current_weight']} lbs\nTarget: ${_recommendations!['weight_goal']['target_weight']} lbs',
                      CupertinoIcons.chart_bar,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),

          // Weightlifting Goals Section
          _buildWeightliftingSection(),

          // Nutrition Goals Section using the new method
          _buildNutritionSection(),

          const SizedBox(height: 8),

          _buildStyledButton(
            text: 'Add All Recommendations',
            onPressed: _createRecommendedGoals,
          ),
        ],
      ),
    );
  }
} 