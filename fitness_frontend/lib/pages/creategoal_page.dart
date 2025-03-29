import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/colors.dart';

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
  bool _isCreatingGoal = false;

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

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: CupertinoColors.white),
        ),
        backgroundColor: isError ? CupertinoColors.destructiveRed : kPrimaryBlue,
      ),
    );
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
      _showSnackBar('Error loading exercises: ${e.toString()}', isError: true);
      setState(() => _isLoadingExercises = false);
    }
  }

  void _updateTimeFrameBasedOnCategory(String category) {
    setState(() {
      if (_dailyGoals.contains(category)) {
        _selectedTimeFrame = 'daily';
        _selectedDate = DateTime.now();
      } else if (_longTermGoals.contains(category)) {
        _selectedTimeFrame = 'long_term';
        _selectedDate = DateTime.now().add(const Duration(days: 30));
      }
      if (category != 'weightlifting') {
        _selectedExercise = null;
      } else if (_exercises.isNotEmpty) {
        _selectedExercise = _exercises[0]['name'];
      }
    });
  }

  void _showDatePicker() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 216,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: CupertinoDatePicker(
            initialDateTime: _selectedDate,
            mode: CupertinoDatePickerMode.date,
            use24hFormat: true,
            minimumDate: DateTime.now(),
            maximumDate: DateTime.now().add(const Duration(days: 365 * 2)),
            onDateTimeChanged: (DateTime newDate) {
              setState(() => _selectedDate = newDate);
            },
          ),
        ),
      ),
    );
  }

  void _showCategoryPicker() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 216,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: CupertinoPicker(
            magnification: 1.22,
            squeeze: 1.2,
            useMagnifier: true,
            itemExtent: 32.0,
            scrollController: FixedExtentScrollController(
              initialItem: _categories.indexOf(_selectedCategory),
            ),
            onSelectedItemChanged: (int selectedItem) {
              setState(() {
                _selectedCategory = _categories[selectedItem];
                _updateTimeFrameBasedOnCategory(_categories[selectedItem]);
              });
            },
            children: _categories.map((category) {
              return Center(child: Text(category.toUpperCase()));
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showExercisePicker() {
    if (_exercises.isEmpty) return;
    
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 216,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: CupertinoPicker(
            magnification: 1.22,
            squeeze: 1.2,
            useMagnifier: true,
            itemExtent: 32.0,
            scrollController: FixedExtentScrollController(
              initialItem: _exercises.indexWhere((e) => e['name'] == _selectedExercise),
            ),
            onSelectedItemChanged: (int selectedItem) {
              setState(() {
                _selectedExercise = _exercises[selectedItem]['name'] as String;
              });
            },
            children: _exercises.map((exercise) {
              return Center(child: Text(exercise['name'] as String));
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _createGoal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreatingGoal = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String token = prefs.getString('token') ?? '';

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
        _showSnackBar('Goal created successfully');
      } else {
        throw Exception('Failed to create goal');
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isCreatingGoal = false);
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

  String _getTargetDescription() {
    if (_dailyGoals.contains(_selectedCategory)) {
      return 'Daily Target';
    } else {
      return 'Target Value';
    }
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    String? placeholder,
    String? suffix,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.systemGrey5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: kSecondaryText,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            suffix: suffix != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      suffix,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : null,
            keyboardType: TextInputType.number,
            decoration: BoxDecoration(
              border: Border.all(color: CupertinoColors.systemGrey4),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(12),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CupertinoColors.systemGrey5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: kSecondaryText,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    color: CupertinoColors.black,
                  ),
                ),
                const Icon(
                  CupertinoIcons.chevron_down,
                  color: CupertinoColors.systemGrey,
                  size: 20,
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
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(
            CupertinoIcons.back,
            color: kPrimaryBlue,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Goal',
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSelectionField(
                  label: 'Goal Type',
                  value: _selectedCategory.toUpperCase(),
                  onTap: _showCategoryPicker,
                ),
                const SizedBox(height: 16),
                if (_selectedCategory == 'weightlifting') ...[
                  if (_isLoadingExercises)
                    const Center(child: CupertinoActivityIndicator())
                  else
                    _buildSelectionField(
                      label: 'Exercise',
                      value: _selectedExercise ?? 'Select Exercise',
                      onTap: _showExercisePicker,
                    ),
                  const SizedBox(height: 16),
                ],
                _buildInputField(
                  controller: _targetValueController,
                  label: _getTargetDescription(),
                  placeholder: _getHelperText(),
                  suffix: _getUnitForCategory(_selectedCategory),
                ),
                if (_selectedCategory == 'weight') ...[
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _currentValueController,
                    label: "Today's Weight",
                    placeholder: 'Enter your current weight',
                    suffix: 'kg',
                  ),
                ],
                if (!_dailyGoals.contains(_selectedCategory)) ...[
                  const SizedBox(height: 16),
                  _buildSelectionField(
                    label: 'Target Date',
                    value: '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                    onTap: _showDatePicker,
                  ),
                ],
                const SizedBox(height: 32),
                if (_isCreatingGoal)
                  const Center(child: CupertinoActivityIndicator())
                else
                  CupertinoButton(
                    color: kPrimaryBlue,
                    onPressed: _createGoal,
                    child: const Text('Create Goal'),
                  ),
              ],
            ),
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