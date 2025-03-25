import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CreateGoalPage extends StatefulWidget {
  const CreateGoalPage({super.key});

  @override
  State<CreateGoalPage> createState() => _CreateGoalPageState();
}

class _CreateGoalPageState extends State<CreateGoalPage> {
  final _formKey = GlobalKey<FormState>();
  final _targetValueController = TextEditingController();
  final _currentValueController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 30));
  String _selectedCategory = 'weight';
  String _selectedTimeFrame = 'long_term';
  String? _selectedExercise;
  List<Map<String, dynamic>> _exercises = [];
  bool _isLoadingExercises = false;

  final List<String> _categories = [
    'weight',
    'steps',
    'calories',
    'protein',
    'carbs',
    'fats',
    'distance',
    'weightlifting',
    'other'
  ];

  // Define which categories are daily goals
  final Set<String> _dailyGoals = {'calories', 'steps', 'protein', 'carbs', 'fats', 'weight'};
  
  // Define which categories are long-term goals
  final Set<String> _longTermGoals = {'distance', 'weightlifting', 'other'};

  @override
  void initState() {
    super.initState();
    _fetchExercises();
  }

  Future<void> _fetchExercises() async {
    setState(() => _isLoadingExercises = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/exercise_types'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _exercises = List<Map<String, dynamic>>.from(data);
          _isLoadingExercises = false;
          if (_selectedCategory == 'weightlifting' && _exercises.isNotEmpty) {
            _selectedExercise = _exercises[0]['name'];
          }
        });
      } else {
        throw Exception('Failed to load exercises');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading exercises: ${e.toString()}')),
      );
      setState(() => _isLoadingExercises = false);
    }
  }

  void _updateTimeFrameBasedOnCategory(String category) {
    setState(() {
      if (_dailyGoals.contains(category)) {
        _selectedTimeFrame = 'daily';
        // For daily goals, set target date to end of day
        _selectedDate = DateTime.now();
      } else if (_longTermGoals.contains(category)) {
        _selectedTimeFrame = 'long_term';
        // For long-term goals, set target date to 30 days from now
        _selectedDate = DateTime.now().add(const Duration(days: 30));
      }
      // Reset selected exercise when changing category
      if (category != 'weightlifting') {
        _selectedExercise = null;
      } else if (_exercises.isNotEmpty) {
        _selectedExercise = _exercises[0]['name'];
      }
    });
  }

  String _getTimeFrameDescription() {
    if (_dailyGoals.contains(_selectedCategory)) {
      return 'Daily Goal';
    } else {
      return 'Target Date';
    }
  }

  String _getTargetDescription() {
    if (_dailyGoals.contains(_selectedCategory)) {
      return 'Daily Target';
    } else {
      return 'Target Value';
    }
  }

  Future<void> _createGoal() async {
    if (!_formKey.currentState!.validate()) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    try {
      // For weightlifting goals, combine the type and exercise name in the title
      final goalTitle = _selectedCategory == 'weightlifting' ? 
          '$_selectedCategory:${_selectedExercise}' : _selectedCategory;

      final response = await http.post(
        Uri.parse('http://localhost:8000/users/goals'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'goal_type': goalTitle,
          'target_value': double.parse(_targetValueController.text),
          'current_value': _selectedCategory == 'weight' ? 
              double.parse(_currentValueController.text) : 0.0,
          'start_date': DateTime.now().toIso8601String().split('T')[0],
          'target_date': _selectedDate.toIso8601String().split('T')[0],
          'time_frame': _selectedTimeFrame,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal created successfully')),
        );
      } else {
        throw Exception('Failed to create goal');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  String _getUnitForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'weight':
        return 'kg';
      case 'steps':
        return 'steps';
      case 'calories':
        return 'kcal';
      case 'protein':
        return 'g';
      case 'carbs':
        return 'g';
      case 'fats':
        return 'g';
      case 'distance':
        return 'km';
      case 'weightlifting':
        return 'kg';
      default:
        return '';
    }
  }

  String _getHelperText() {
    if (_dailyGoals.contains(_selectedCategory)) {
      return 'Enter your daily target';
    } else {
      return 'Enter your goal target';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Goal'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Goal Type',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                    _updateTimeFrameBasedOnCategory(value);
                  });
                },
              ),
              const SizedBox(height: 16),
              if (_selectedCategory == 'weightlifting') ...[
                _isLoadingExercises
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<String>(
                        value: _selectedExercise,
                        decoration: const InputDecoration(
                          labelText: 'Exercise',
                          border: OutlineInputBorder(),
                        ),
                        items: _exercises.map<DropdownMenuItem<String>>((exercise) {
                          return DropdownMenuItem<String>(
                            value: exercise['name'] as String,
                            child: Text(exercise['name'] as String),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedExercise = value!;
                          });
                        },
                      ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _targetValueController,
                decoration: InputDecoration(
                  labelText: _getTargetDescription(),
                  helperText: _getHelperText(),
                  border: const OutlineInputBorder(),
                  suffixText: _getUnitForCategory(_selectedCategory),
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
              if (_selectedCategory == 'weight') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _currentValueController,
                  decoration: const InputDecoration(
                    labelText: 'Today\'s Weight',
                    border: OutlineInputBorder(),
                    suffixText: 'kg',
                    helperText: 'Enter your current weight for today',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your current weight';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              if (!_dailyGoals.contains(_selectedCategory)) ...[
                ListTile(
                  title: Text(_getTimeFrameDescription()),
                  subtitle: Text(
                    '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate = picked;
                      });
                    }
                  },
                ),
              ] else ...[
                ListTile(
                  title: Text(_getTimeFrameDescription()),
                  subtitle: _selectedCategory == 'weight' 
                      ? const Text('Track your weight daily')
                      : const Text('Resets daily at midnight'),
                  leading: const Icon(Icons.refresh),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _createGoal,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Create Goal'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _targetValueController.dispose();
    _currentValueController.dispose();
    super.dispose();
  }
} 