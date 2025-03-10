import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Add Timer import

class WorkoutsPage extends StatefulWidget {
  const WorkoutsPage({super.key});

  @override
  _WorkoutsPageState createState() => _WorkoutsPageState();
}

class _WorkoutsPageState extends State<WorkoutsPage> {
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

  void _showEditWorkoutDialog(Map workout) {
    final nameController = TextEditingController(text: workout['name']);
    final dateController = TextEditingController(text: workout['date']);
    final durationController = TextEditingController(text: workout['duration'].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Workout'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Workout Name'),
              ),
              TextField(
                controller: dateController,
                decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.tryParse(workout['date']) ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    dateController.text = picked.toIso8601String().split('T')[0];
                  }
                },
              ),
              TextField(
                controller: durationController,
                decoration: const InputDecoration(labelText: 'Duration (minutes)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Workouts")),
      body: Column(
        children: [
          const SizedBox(height: 20),
          const Text("Your Workouts:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

          // Buttons for Creating Workout & Exercise
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.pushNamed(context, '/create-workout');
                    if (result == true) {
                      _fetchWorkouts();
                    }
                  },
                  child: const Text("Create Workout"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.pushNamed(context, '/create-exercise');
                    if (result == true) {
                      _fetchWorkouts();
                    }
                  },
                  child: const Text("Create Exercise"),
                ),
              ],
            ),
          ),

          // Workouts List
          Expanded(
            child: ListView.builder(
              itemCount: workouts.length,
              itemBuilder: (context, index) {
                final workout = workouts[index];
                final workoutId = workout['id'];

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: ExpansionTile(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(workout['name']),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showEditWorkoutDialog(workout),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteWorkout(workoutId),
                        ),
                      ],
                    ),
                    subtitle: Text("Date: ${workout['date']} | Duration: ${workout['duration']} min"),
                    children: [
                      // Search and Add Exercise Section
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            // Search Box
                            TextField(
                              controller: _getSearchController(workoutId),
                              decoration: const InputDecoration(
                                labelText: 'Search Exercises',
                                prefixIcon: Icon(Icons.search),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) async {
                                // Cancel any existing timer for this workout
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
                                  // Start a new timer
                                  _searchDebounceTimers[workoutId] = Timer(const Duration(milliseconds: 500), () {
                                    if (mounted) {
                                      setState(() {
                                        // Store the future for this search
                                        _searchFutures[workoutId] = searchExercises(value);
                                      });
                                    }
                                  });
                                }
                              },
                            ),

                            const SizedBox(height: 8),

                            // Exercise Search Results
                            if (isSearchingWorkout[workoutId] == true)
                              FutureBuilder<List<Map<String, dynamic>>>(
                                future: _searchFutures[workoutId] ?? Future.value([]),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const Center(child: CircularProgressIndicator());
                                  } else if (snapshot.hasError) {
                                    return const Center(child: Text("Error loading search results"));
                                  } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                                    return Container(
                                      height: 200,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: snapshot.data!.length,
                                        itemBuilder: (context, index) {
                                          final exercise = snapshot.data![index];
                                          return ListTile(
                                            title: Text(exercise['name'] ?? 'Unnamed Exercise'),
                                            subtitle: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(exercise['category'] ?? 'Uncategorized'),
                                                if ((exercise['muscles'] ?? '').toString().isNotEmpty)
                                                  Text(
                                                    'Muscles: ${exercise['muscles']}',
                                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                                  ),
                                              ],
                                            ),
                                            trailing: IconButton(
                                              icon: const Icon(Icons.add_circle, color: Colors.blue),
                                              onPressed: () {
                                                // Quick add with default sets
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
                                            onTap: () async {
                                              // Navigate to exercise log page for custom sets
                                              final sanitizedExercise = {
                                                'id': exercise['id'] ?? 0,
                                                'name': exercise['name'] ?? 'Unnamed Exercise',
                                                'category': exercise['category'] ?? 'Uncategorized',
                                                'muscles': exercise['muscles'] ?? '',
                                                'description': exercise['description'] ?? '',
                                                'is_predefined': exercise['is_predefined'] ?? false,
                                              };
                                              
                                              final result = await Navigator.pushNamed(
                                                context,
                                                '/exercise-log',
                                                arguments: {
                                                  'workoutId': workoutId,
                                                  'exerciseToAdd': sanitizedExercise,
                                                  'exerciseName': exercise['name'] ?? 'Unnamed Exercise',
                                                  'isNewExercise': true,
                                                },
                                              );

                                              if (result == true) {
                                                setState(() {
                                                  exerciseTypes = [];
                                                  workoutSearchQueries[workoutId] = '';
                                                  isSearchingWorkout[workoutId] = false;
                                                });
                                                _getSearchController(workoutId).clear();
                                                _fetchWorkoutExercises(workoutId);
                                              }
                                            },
                                            isThreeLine: (exercise['muscles'] ?? '').toString().isNotEmpty,
                                          );
                                        },
                                      ),
                                    );
                                  } else {
                                    return const Text("No exercises found");
                                  }
                                },
                              ),

                            const Divider(),

                            // Added Exercises Section
                            if (workoutExercises.containsKey(workoutId) &&
                                workoutExercises[workoutId]!.isNotEmpty)
                              ...workoutExercises[workoutId]!.map((exercise) {
                                return ListTile(
                                  title: Text(exercise['exercise_name']),
                                  subtitle: Text("Sets: ${exercise['sets']}"),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.remove_circle, color: Colors.red),
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
                                );
                              }).toList()
                            else
                              const Text("No exercises added yet"),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}