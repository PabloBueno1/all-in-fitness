import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Add Timer import
import '../widgets/bottom_nav_bar.dart';
import '../mixins/navigation_mixin.dart';
import '../constants/colors.dart';

class WorkoutsPage extends StatefulWidget {
  const WorkoutsPage({super.key});

  @override
  State<WorkoutsPage> createState() => _WorkoutsPageState();
}

class _WorkoutsPageState extends State<WorkoutsPage> with NavigationMixin {
  List workouts = [];
  List exerciseTypes = []; // Changed back to List like meals page
  Map<int, List> workoutExercises = {}; // Stores exercises for each workout
  Map<int, String> workoutSearchQueries = {}; // Workout-specific search text
  Map<int, bool> isSearchingWorkout = {}; // For tracking search status per workout
  Map<int, TextEditingController> _searchControllers = {};
  Map<int, Timer?> _searchDebounceTimers = {}; // Add debounce timers map
  Map<int, Future<List<Map<String, dynamic>>>> _searchFutures = {}; // Store search futures
  final int defaultSets = 3;

  final String searchApiUrl = 'http://localhost:8000/exercise_types/search';
  final String postApiUrl = 'http://localhost:8000/exercise_types';

  @override
  void initState() {
    super.initState();
    _fetchWorkouts();
  }

  @override
  void dispose() {
    for (var controller in _searchControllers.values) {
      controller.dispose();
    }
    // Cancel all active timers
    for (var timer in _searchDebounceTimers.values) {
      timer?.cancel();
    }
    super.dispose();
  }

  /// Get or create search controller for a workout
  TextEditingController _getSearchController(int workoutId) {
    if (!_searchControllers.containsKey(workoutId)) {
      _searchControllers[workoutId] = TextEditingController(text: workoutSearchQueries[workoutId] ?? '');
    }
    return _searchControllers[workoutId]!;
  }

  /// Fetch all workouts
  Future<void> _fetchWorkouts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final response = await http.get(
      Uri.parse('http://localhost:8000/workouts'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      List decodedResponse = json.decode(response.body);
      setState(() {
        workouts = decodedResponse.map((workout) {
          return {
            'id': workout['id'] ?? -1,
            'name': workout['name'] ?? 'Unknown Workout',
            'date': workout['date']?.toString() ?? 'Unknown Date',
            'duration': workout['duration'] ?? 0,
          };
        }).toList();
      });

      for (var workout in workouts) {
        _fetchWorkoutExercises(workout['id']);
      }
    } else {
      print("Failed to fetch workouts: ${response.statusCode}");
    }
  }

  /// Delete Workout
  Future<void> _deleteWorkout(int workoutId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    try {
      // First, delete all exercise logs for this workout
      final logsResponse = await http.delete(
        Uri.parse('http://localhost:8000/workouts/$workoutId/logs'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (logsResponse.statusCode != 200) {
        print("Failed to delete exercise logs: ${logsResponse.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to delete workout logs.")),
        );
        return;
      }

      // Then delete all exercises in the workout
      final exercisesResponse = await http.delete(
        Uri.parse('http://localhost:8000/workouts/$workoutId/exercises'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (exercisesResponse.statusCode != 200) {
        print("Failed to delete workout exercises: ${exercisesResponse.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to delete workout exercises.")),
        );
        return;
      }

      // Finally delete the workout itself
      final response = await http.delete(
        Uri.parse('http://localhost:8000/workouts/$workoutId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          workouts.removeWhere((workout) => workout['id'] == workoutId);
          workoutExercises.remove(workoutId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Workout deleted successfully!")),
        );
      } else {
        print("Failed to delete workout: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to delete workout.")),
        );
      }
    } catch (e) {
      print("Error during workout deletion: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("An error occurred while deleting the workout.")),
      );
    }
  }

  /// Search exercise types (returns List of exercises)
  Future<List<Map<String, dynamic>>> searchExercises(String query) async {
    if (query.isEmpty) return [];

    try {
      print("🔍 Searching for exercises: $query");
      final response = await http.get(Uri.parse('$searchApiUrl?query=$query'));

      if (response.statusCode == 200) {
        List<dynamic> exercises = json.decode(response.body);
        print("✅ Search results: $exercises");
        return exercises.cast<Map<String, dynamic>>();
      } else {
        print("❌ Search API Error: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("⚠️ Error during search: $e");
      return [];
    }
  }

  /// Add exercise to DB if from external API
  Future<Map<String, dynamic>?> addExerciseToDB(Map<String, dynamic> exercise) async {
    if (exercise['id'] == 0) {
      final response = await http.post(
        Uri.parse(postApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(exercise),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final savedExercise = json.decode(response.body);
        return {
          ...exercise,
          'id': savedExercise['id'],
        };
      } else {
        return null;
      }
    }
    return exercise;
  }

  /// Fetch exercises for a specific workout
  Future<void> _fetchWorkoutExercises(int workoutId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final response = await http.get(
      Uri.parse('http://localhost:8000/exercises/$workoutId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      List decodedResponse = json.decode(response.body);
      setState(() {
        workoutExercises[workoutId] = decodedResponse;
      });
    } else {
      setState(() {
        workoutExercises[workoutId] = [];
      });
    }
  }

  /// Add exercise to workout
  Future<void> _addExerciseToWorkout(int workoutId, Map<String, dynamic> exercise) async {
    // Check if exercise is already in the workout
    if (workoutExercises[workoutId]?.any((e) => e['exercise_id'] == exercise['id']) ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This exercise is already in your workout!")),
      );
      return;
    }

    // First, ensure exercise is in DB if it's from external API
    final dbExercise = await addExerciseToDB(exercise);
    if (dbExercise == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save exercise to database.")),
      );
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final response = await http.post(
      Uri.parse('http://localhost:8000/exercises'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        "workout_id": workoutId,
        "exercise_id": dbExercise['id'],
        "sets": defaultSets,
      }),
    );

    if (response.statusCode == 200) {
      // Clear search results, search field, and reset state
      setState(() {
        exerciseTypes = [];
        workoutSearchQueries[workoutId] = '';
        isSearchingWorkout[workoutId] = false;
      });
      _getSearchController(workoutId).clear();
      _fetchWorkoutExercises(workoutId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Exercise added successfully!")),
      );
    } 
    else if (response.statusCode == 409) {
        // Conflict - Exercise already exists
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This exercise is already in your workout!")),
        );
      }
    else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to add exercise.")),
      );
    }
  }

  /// Remove exercise from workout
  Future<void> _removeExerciseFromWorkout(int workoutId, int exerciseId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final response = await http.delete(
      Uri.parse('http://localhost:8000/workouts/$workoutId/exercises/$exerciseId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      _fetchWorkoutExercises(workoutId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Exercise removed successfully!")),
      );
    } else {
      print("Failed to remove exercise: ${response.body}");
    }
  }

  /// Update workout details
  Future<void> _updateWorkout(int workoutId, String name, String date, int duration) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    try {
      final response = await http.patch(
        Uri.parse('http://localhost:8000/workouts/$workoutId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': name,
          'date': date,
          'duration': duration,
        }),
      );

      if (response.statusCode == 200) {
        _fetchWorkouts(); // Refresh the workouts list
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Workout updated successfully!")),
        );
      } else {
        print("Failed to update workout: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update workout.")),
        );
      }
    } catch (e) {
      print("Error during workout update: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("An error occurred while updating the workout.")),
      );
    }
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

  void _showEditWorkoutDialog(Map workout) {
    final nameController = TextEditingController(text: workout['name']);
    final dateController = TextEditingController(text: workout['date']);
    final durationController = TextEditingController(text: workout['duration'].toString());

    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Edit Workout'),
        message: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoTextField(
                controller: nameController,
                placeholder: 'Workout Name',
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: CupertinoColors.systemGrey4),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
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
                          initialDateTime: DateTime.tryParse(workout['date']) ?? DateTime.now(),
                          mode: CupertinoDatePickerMode.date,
                          use24hFormat: true,
                          onDateTimeChanged: (DateTime newDate) {
                            dateController.text = newDate.toIso8601String().split('T')[0];
                          },
                        ),
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.systemGrey4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dateController.text,
                        style: const TextStyle(color: CupertinoColors.black),
                      ),
                      const Icon(
                        CupertinoIcons.calendar,
                        color: CupertinoColors.systemGrey,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: durationController,
                placeholder: 'Duration (minutes)',
                keyboardType: TextInputType.number,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: CupertinoColors.systemGrey4),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              _updateWorkout(
                workout['id'],
                nameController.text,
                dateController.text,
                int.tryParse(durationController.text) ?? workout['duration'],
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
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
        title: const Text(
          'Workouts',
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: workouts.length,
                itemBuilder: (context, index) {
                  final workout = workouts[index];
                  final workoutId = workout['id'];

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
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        title: Row(
                          children: [
                            Icon(CupertinoIcons.sportscourt,
                                color: kPrimaryBlue, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    workout['name'],
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                  Text(
                                    "Date: ${workout['date']} | Duration: ${workout['duration']} min",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
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
                                        child: const Text('Edit Workout'),
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _showEditWorkoutDialog(workout);
                                        },
                                      ),
                                      CupertinoActionSheetAction(
                                        isDestructiveAction: true,
                                        child: const Text('Delete Workout'),
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _deleteWorkout(workoutId);
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
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: CupertinoSearchTextField(
                                        controller: _getSearchController(workoutId),
                                        placeholder: "Search Exercises to Add",
                                        onChanged: (value) {
                                          _searchDebounceTimers[workoutId]?.cancel();
                                          setState(() {
                                            workoutSearchQueries[workoutId] = value;
                                            if (value.isEmpty) {
                                              exerciseTypes = [];
                                              isSearchingWorkout[workoutId] = false;
                                              _searchFutures[workoutId] = Future.value([]);
                                            } else {
                                              isSearchingWorkout[workoutId] = true;
                                            }
                                          });

                                          if (value.isNotEmpty) {
                                            _searchDebounceTimers[workoutId] = Timer(
                                              const Duration(milliseconds: 500),
                                              () {
                                                if (mounted) {
                                                  setState(() {
                                                    _searchFutures[workoutId] = searchExercises(value);
                                                  });
                                                }
                                              },
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                if (isSearchingWorkout[workoutId] ?? false)
                                  Column(
                                    children: [
                                      const SizedBox(height: 16),
                                      FutureBuilder<List<Map<String, dynamic>>>(
                                        future: _searchFutures[workoutId] ?? Future.value([]),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState == ConnectionState.waiting) {
                                            return const Center(child: CupertinoActivityIndicator());
                                          } else if (snapshot.hasError) {
                                            return Center(
                                              child: Text(
                                                "Error loading search results",
                                                style: TextStyle(color: CupertinoColors.destructiveRed),
                                              ),
                                            );
                                          } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                                            return Container(
                                              height: 200,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[50],
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: ListView.builder(
                                                shrinkWrap: true,
                                                physics: const NeverScrollableScrollPhysics(),
                                                itemCount: snapshot.data!.length,
                                                itemBuilder: (context, index) {
                                                  final exercise = snapshot.data![index];
                                                  return Container(
                                                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[50],
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: CupertinoListTile(
                                                      title: Text(
                                                        exercise['name'] ?? 'Unnamed Exercise',
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                      trailing: CupertinoButton(
                                                        padding: EdgeInsets.zero,
                                                        child: Text(
                                                          'Add',
                                                          style: TextStyle(color: kPrimaryBlue),
                                                        ),
                                                        onPressed: () {
                                                          final sanitizedExercise = {
                                                            'id': exercise['id'] ?? 0,
                                                            'name': exercise['name'] ?? 'Unnamed Exercise',
                                                            'category': exercise['category'] ?? 'Uncategorized',
                                                            'muscles': exercise['muscles'] ?? '',
                                                            'description': exercise['description'] ?? '',
                                                            'is_predefined': exercise['is_predefined'] ?? false,
                                                          };
                                                          _addExerciseToWorkout(workoutId, sanitizedExercise);
                                                        },
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            );
                                          } else {
                                            return const Text(
                                              "No exercises found",
                                              style: TextStyle(color: kSecondaryText),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                if (!(isSearchingWorkout[workoutId] ?? false) && workoutExercises.containsKey(workoutId) &&
                                    workoutExercises[workoutId]!.isNotEmpty)
                                  Column(
                                    children: [
                                      const SizedBox(height: 16),
                                      ...workoutExercises[workoutId]!.map((exercise) {
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[50],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: CupertinoListTile(
                                            title: Text(
                                              exercise['exercise_name'],
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            subtitle: Text(
                                              "Sets: ${exercise['sets']}",
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            leading: Icon(CupertinoIcons.pencil_circle,
                                                color: kPrimaryBlue),
                                            trailing: CupertinoButton(
                                              padding: EdgeInsets.zero,
                                              child: const Icon(
                                                CupertinoIcons.minus_circle,
                                                color: CupertinoColors.destructiveRed,
                                              ),
                                              onPressed: () =>
                                                  _removeExerciseFromWorkout(workoutId, exercise['exercise_id']),
                                            ),
                                            onTap: () async {
                                              final result = await Navigator.pushNamed(
                                                context,
                                                '/exercise-log',
                                                arguments: {
                                                  'workoutId': workoutId,
                                                  'exerciseId': exercise['exercise_id'],
                                                  'exerciseName': exercise['exercise_name'],
                                                  'setCap': exercise['sets'],
                                                },
                                              );

                                              if (result == true) {
                                                _fetchWorkoutExercises(workoutId);
                                              }
                                            },
                                          ),
                                        );
                                      }).toList(),
                                    ],
                                  )
                                else if (!(isSearchingWorkout[workoutId] ?? false))
                                  const Padding(
                                    padding: EdgeInsets.only(top: 16),
                                    child: Text(
                                      "No exercises added yet",
                                      style: TextStyle(color: kSecondaryText),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
          onPressed: () {
            final RenderBox button = context.findRenderObject() as RenderBox;
            final position = button.localToGlobal(Offset.zero);
            
            showCupertinoModalPopup(
              context: context,
              barrierDismissible: true,
              builder: (context) => TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Positioned(
                      top: position.dy - 220,
                      right: 16,
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          width: 220,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey[200]!,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Add New',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      child: const Icon(CupertinoIcons.xmark),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ],
                                ),
                              ),
                              CupertinoButton(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                pressedOpacity: 0.7,
                                color: Colors.transparent,
                                child: Row(
                                  children: [
                                    Icon(CupertinoIcons.sportscourt_fill, color: kPrimaryBlue),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Create Workout',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                onPressed: () async {
                                  Navigator.pop(context);
                                  final result = await Navigator.pushNamed(context, '/create-workout');
                                  if (result == true) {
                                    _fetchWorkouts();
                                  }
                                },
                              ),
                              CupertinoButton(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                pressedOpacity: 0.7,
                                color: Colors.transparent,
                                child: Row(
                                  children: [
                                    Icon(CupertinoIcons.plus_circle_fill, color: kPrimaryBlue),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Create Exercise',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                onPressed: () async {
                                  Navigator.pop(context);
                                  final result = await Navigator.pushNamed(context, '/create-exercise');
                                  if (result == true) {
                                    _fetchWorkouts();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
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