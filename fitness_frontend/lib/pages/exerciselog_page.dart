import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/colors.dart';

class ExerciseLogPage extends StatefulWidget {
  const ExerciseLogPage({Key? key}) : super(key: key);

  @override
  _ExerciseLogPageState createState() => _ExerciseLogPageState();
}

class _ExerciseLogPageState extends State<ExerciseLogPage> {
  late int workoutId;
  late int exerciseId;
  late int setCap;
  late String exerciseName;
  late String muscles;
  late String description;
  late String category;
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _setsController = TextEditingController(text: '3');  // For new exercises
  late Future<List<Map<String, dynamic>>> _logsFuture;
  late bool isNewExercise;
  late Map<String, dynamic> exerciseToAdd;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    workoutId = args['workoutId'];
    isNewExercise = args['isNewExercise'] ?? false;
    
    if (isNewExercise) {
      exerciseToAdd = args['exerciseToAdd'];
      exerciseName = exerciseToAdd['name'];
      muscles = exerciseToAdd['muscles'] ?? '';
      description = exerciseToAdd['description'] ?? '';
      category = exerciseToAdd['category'] ?? 'Uncategorized';
      _logsFuture = Future.value([]);  // No logs for new exercise
    } else {
      exerciseId = args['exerciseId'];
      exerciseName = args['exerciseName'];
      muscles = args['muscles'] ?? '';
      description = args['description'] ?? '';
      category = args['category'] ?? 'Uncategorized';
      setCap = args['setCap'];
      _logsFuture = _fetchExerciseLogs(workoutId, exerciseId);
    }
  }

  // Fetch Exercise Logs for a Workout & Exercise
  Future<List<Map<String, dynamic>>> _fetchExerciseLogs(int workoutId, int exerciseId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final response = await http.get(
      Uri.parse('http://localhost:8000/exercise_logs/$workoutId/$exerciseId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      List<dynamic> logs = json.decode(response.body);
      return logs.cast<Map<String, dynamic>>();
    } else {
      return [];
    }
  }

  //Log single exercise
  Future<void> _logSingleExerciseSet(int workoutId, int exerciseId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    if (token.isEmpty) {
      _showSnackBar("Error: No token found. Please log in.");
      return;
    }
    List<Map<String, dynamic>> currentLogs = await _fetchExerciseLogs(workoutId, exerciseId);
    int nextSetNumber = currentLogs.length + 1;

     if (currentLogs.length >= setCap) {
      _showSnackBar("You've reached the maximum number of sets.");
      return;
    }

    int? weight = int.tryParse(_weightController.text);
    int? reps = int.tryParse(_repsController.text);

    if (weight == null || reps == null) {
      _showSnackBar("Please enter valid weight and reps.");
      return;
    }

    final response = await http.post(
      Uri.parse('http://localhost:8000/exercise_logs'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        "exercise_id": exerciseId,
        "set_number": nextSetNumber,
        "weight": weight,
        "reps": reps,
      }),
    );

    if (response.statusCode == 200) {
      _weightController.clear();
      _repsController.clear();
      setState(() {
        _logsFuture = _fetchExerciseLogs(workoutId, exerciseId);
      });

      _showSnackBar("Set logged successfully!");
    } else {
      _showSnackBar("Failed to log set.");
    }
  }

  // Delete Log
  Future<void> _deleteExerciseLog(int logId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final response = await http.delete(
      Uri.parse('http://localhost:8000/exercise_logs/$logId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      _showSnackBar("Log deleted successfully!");

      // Refresh logs after deletion
      setState(() {
        _logsFuture = _fetchExerciseLogs(workoutId, exerciseId);  // Refresh the list
      });
    } else if (response.statusCode == 404) {
      _showSnackBar("Log not found.");
    } else {
      _showSnackBar("Failed to delete log.");
    }
  }

  // Edit Exercise Log
  void _showEditLogDialog(Map<String, dynamic> log) {
    final TextEditingController weightController = TextEditingController(text: log['weight'].toString());
    final TextEditingController repsController = TextEditingController(text: log['reps'].toString());
    final int logId = log['id'];
    final int initialWeight = log['weight'];
    final int initialReps = log['reps'];

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Material(
          type: MaterialType.transparency,
          child: Text(
            'Edit Set',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.label,
            ),
          ),
        ),
        message: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CupertinoColors.systemGrey5),
              ),
              child: CupertinoTextField(
                controller: weightController,
                keyboardType: TextInputType.number,
                placeholder: 'Weight (lbs)',
                padding: const EdgeInsets.all(12),
                decoration: null,
                placeholderStyle: const TextStyle(
                  color: CupertinoColors.placeholderText,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CupertinoColors.systemGrey5),
              ),
              child: CupertinoTextField(
                controller: repsController,
                keyboardType: TextInputType.number,
                placeholder: 'Reps',
                padding: const EdgeInsets.all(12),
                decoration: null,
                placeholderStyle: const TextStyle(
                  color: CupertinoColors.placeholderText,
                ),
              ),
            ),
          ],
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              int? newWeight = int.tryParse(weightController.text);
              int? newReps = int.tryParse(repsController.text);

              if (newWeight == null && newReps == null) {
                _showSnackBar("Please enter valid weight or reps.");
                return;
              }

              SharedPreferences prefs = await SharedPreferences.getInstance();
              String token = prefs.getString('token') ?? '';

              Map<String, dynamic> updateData = {};
              if (newWeight != initialWeight) updateData['weight'] = newWeight;
              if (newReps != initialReps) updateData['reps'] = newReps;

              final response = await http.patch(
                Uri.parse('http://localhost:8000/exercise_logs/$logId'),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                },
                body: json.encode(updateData),
              );

              if (response.statusCode == 200) {
                setState(() {
                  _logsFuture = _fetchExerciseLogs(workoutId, exerciseId);
                });
                Navigator.pop(context);
                _showSnackBar("Log updated successfully!");
              } else {
                _showSnackBar("Failed to update log.");
              }
            },
            isDefaultAction: true,
            child: const Text(
              'Save',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDestructiveAction: true,
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  /// Add new exercise to workout with custom sets
  Future<void> _addNewExerciseToWorkout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    int? sets = int.tryParse(_setsController.text);
    if (sets == null || sets <= 0) {
      _showSnackBar("Please enter a valid number of sets");
      return;
    }

    // First ensure exercise is in DB if from external API
    if (exerciseToAdd['id'] == 0) {
      final response = await http.post(
        Uri.parse('http://localhost:8000/exercise_types'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(exerciseToAdd),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final savedExercise = json.decode(response.body);
        exerciseToAdd = {...exerciseToAdd, 'id': savedExercise['id']};
      } else {
        _showSnackBar("Failed to save exercise.");
        return;
      }
    }

    // Add exercise to workout
    final response = await http.post(
      Uri.parse('http://localhost:8000/exercises'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        "workout_id": workoutId,
        "exercise_id": exerciseToAdd['id'],
        "sets": sets,
      }),
    );

    if (response.statusCode == 200) {
      Navigator.pop(context, true);
      _showSnackBar("Exercise added successfully!");
    } else if (response.statusCode == 409) {
      _showSnackBar("This exercise is already in your workout!");
    } else {
      _showSnackBar("Failed to add exercise.");
    }
  }

  // iOS-style snackbar
  void _showSnackBar(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Material(
          type: MaterialType.transparency,
          child: Text(
            exerciseName,
            style: const TextStyle(
              color: CupertinoColors.label,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        backgroundColor: CupertinoColors.systemBackground,
        border: null,
      ),
      backgroundColor: CupertinoColors.systemBackground,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Exercise Details Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CupertinoColors.systemGrey5),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
                                Material(
                                  type: MaterialType.transparency,
                                  child: Text(
                                    exerciseName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: CupertinoColors.label,
                                    ),
                                  ),
                                ),
                                if (category.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Material(
                                    type: MaterialType.transparency,
                                    child: Text(
                                      category,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: CupertinoColors.secondaryLabel,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: kPrimaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Material(
                              type: MaterialType.transparency,
                              child: Text(
                                isNewExercise ? "New" : "${setCap} sets",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: kPrimaryBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (muscles.isNotEmpty || description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CupertinoColors.systemGrey5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (muscles.isNotEmpty) ...[
                          Material(
                            type: MaterialType.transparency,
                            child: Text(
                              "Muscles",
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.label,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Material(
                            type: MaterialType.transparency,
                            child: Text(
                              muscles,
                              style: const TextStyle(
                                fontSize: 15,
                                color: CupertinoColors.secondaryLabel,
                              ),
                            ),
                          ),
                        ],
                        if (description.isNotEmpty) ...[
                          if (muscles.isNotEmpty)
                            const SizedBox(height: 12),
                          Material(
                            type: MaterialType.transparency,
                            child: Text(
                              "Description",
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.label,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Material(
                            type: MaterialType.transparency,
                            child: Text(
                              description,
                              style: const TextStyle(
                                fontSize: 15,
                                color: CupertinoColors.secondaryLabel,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              if (isNewExercise) ...[
                // Sets input for new exercise
                Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: CupertinoColors.systemGrey5),
                  ),
                  child: CupertinoTextField(
                    controller: _setsController,
                    keyboardType: TextInputType.number,
                    placeholder: "Number of Sets",
                    padding: const EdgeInsets.all(12),
                    decoration: null,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Add button
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: kPrimaryBlue,
                    borderRadius: BorderRadius.circular(8),
                    onPressed: _addNewExerciseToWorkout,
                    child: const Text(
                      "Add to Workout",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Progress indicator
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _logsFuture,
                  builder: (context, snapshot) {
                    double progress = 0.0;
                    if (snapshot.hasData) {
                      progress = snapshot.data!.length / setCap;
                    }
                    return Container(
                      height: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey5,
                          borderRadius: BorderRadius.circular(1),
                        ),
                        child: FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              color: kPrimaryBlue,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Log New Set Card
                Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CupertinoColors.systemGrey5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Material(
                          type: MaterialType.transparency,
                          child: Text(
                            "Log New Set",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.label,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemBackground,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: CupertinoColors.systemGrey5),
                          ),
                          child: CupertinoTextField(
                            controller: _weightController,
                            keyboardType: TextInputType.number,
                            placeholder: "Weight (lbs)",
                            padding: const EdgeInsets.all(12),
                            decoration: null,
                            placeholderStyle: const TextStyle(
                              color: CupertinoColors.placeholderText,
                            ),
                            style: const TextStyle(
                              color: CupertinoColors.label,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemBackground,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: CupertinoColors.systemGrey5),
                          ),
                          child: CupertinoTextField(
                            controller: _repsController,
                            keyboardType: TextInputType.number,
                            placeholder: "Reps",
                            padding: const EdgeInsets.all(12),
                            decoration: null,
                            placeholderStyle: const TextStyle(
                              color: CupertinoColors.placeholderText,
                            ),
                            style: const TextStyle(
                              color: CupertinoColors.label,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: CupertinoButton(
                            color: kPrimaryBlue,
                            borderRadius: BorderRadius.circular(8),
                            onPressed: () => _logSingleExerciseSet(workoutId, exerciseId),
                            child: const Text(
                              "Log Set",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                Material(
                  type: MaterialType.transparency,
                  child: Text(
                    "Logged Sets",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _logsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CupertinoActivityIndicator());
                      }
                      final logs = snapshot.data ?? [];

                      if (logs.isEmpty) {
                        return Center(
                          child: Material(
                            type: MaterialType.transparency,
                            child: Text(
                              "No sets logged yet.\nPlanned sets: $setCap",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 17,
                                color: CupertinoColors.secondaryLabel,
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemBackground,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: CupertinoColors.systemGrey5),
                            ),
                            child: CupertinoListTile(
                              title: Material(
                                type: MaterialType.transparency,
                                child: Text(
                                  "Set ${log['set_number'] ?? 'N/A'}: ${log['weight'] ?? '0'} lbs × ${log['reps'] ?? '0'} reps",
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w500,
                                    color: CupertinoColors.label,
                                  ),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    child: Icon(
                                      CupertinoIcons.pencil,
                                      color: kPrimaryBlue,
                                      size: 20,
                                    ),
                                    onPressed: () => _showEditLogDialog(log),
                                  ),
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    child: Icon(
                                      CupertinoIcons.delete,
                                      color: kPrimaryBlue,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      final logId = log['id'];
                                      if (logId != null) {
                                        _deleteExerciseLog(logId);
                                      } else {
                                        _showSnackBar("Error: Log ID is missing");
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

