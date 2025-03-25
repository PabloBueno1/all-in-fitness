import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
      _logsFuture = Future.value([]);  // No logs for new exercise
    } else {
      exerciseId = args['exerciseId'];
      exerciseName = args['exerciseName'];
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: No token found. Please log in.")),
      );
      return;
    }
    List<Map<String, dynamic>> currentLogs = await _fetchExerciseLogs(workoutId, exerciseId);
    int nextSetNumber = currentLogs.length + 1;

     if (currentLogs.length >= setCap) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You've reached the maximum number of sets.")),
      );
      return;
    }

    int? weight = int.tryParse(_weightController.text);
    int? reps = int.tryParse(_repsController.text);

    if (weight == null || reps == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter valid weight and reps.")),
      );
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Set logged successfully!")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to log set.")),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Log deleted successfully!")),
      );

      // Refresh logs after deletion
      setState(() {
        _logsFuture = _fetchExerciseLogs(workoutId, exerciseId);  // Refresh the list
      });
    } else if (response.statusCode == 404) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Log not found.")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to delete log.")),
      );
    }
  }

  // Edit Exercise Log
  void _showEditLogDialog(Map<String, dynamic> log) {
    final TextEditingController weightController = TextEditingController(text: log['weight'].toString());
    final TextEditingController repsController = TextEditingController(text: log['reps'].toString());
    final int logId = log['id'];
    final int initialWeight = log['weight'];
    final int initialReps = log['reps'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Set'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Weight (lbs)'),
            ),
            TextField(
              controller: repsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Reps'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              int? newWeight = int.tryParse(weightController.text);
              int? newReps = int.tryParse(repsController.text);

              if (newWeight == null && newReps == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter valid weight or reps.")),
                );
                return;
              }

              SharedPreferences prefs = await SharedPreferences.getInstance();
              String token = prefs.getString('token') ?? '';

              // Only include fields that have changed
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Log updated successfully!")),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Failed to update log.")),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Add new exercise to workout with custom sets
  Future<void> _addNewExerciseToWorkout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    int? sets = int.tryParse(_setsController.text);
    if (sets == null || sets <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid number of sets")),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to save exercise.")),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Exercise added successfully!")),
      );
    } else if (response.statusCode == 409) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This exercise is already in your workout!")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to add exercise.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(exerciseName)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exercise Details Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exerciseName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (isNewExercise) ...[
                      Text(
                        "Category: ${exerciseToAdd['category'] ?? 'Uncategorized'}",
                        style: const TextStyle(fontSize: 16),
                      ),
                      if ((exerciseToAdd['muscles'] ?? '').toString().isNotEmpty)
                        Text(
                          "Muscles: ${exerciseToAdd['muscles']}",
                          style: const TextStyle(fontSize: 16),
                        ),
                      if ((exerciseToAdd['description'] ?? '').toString().isNotEmpty)
                        Text(
                          "Description: ${exerciseToAdd['description']}",
                          style: const TextStyle(fontSize: 16),
                        ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      isNewExercise 
                          ? "Add to workout..."
                          : "Sets: $setCap",
                      style: TextStyle(
                        fontSize: 16,
                        color: isNewExercise ? Colors.blue : Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (isNewExercise) ...[
              // Sets input for new exercise
              TextField(
                controller: _setsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Number of Sets",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              
              // Add button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _addNewExerciseToWorkout,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text("Add to Workout"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
                  return LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Existing exercise logging UI
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Log New Set",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Weight (lbs)",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _repsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Reps",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _logSingleExerciseSet(workoutId, exerciseId),
                          icon: const Icon(Icons.add),
                          label: const Text("Log Set"),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              const Text(
                "Logged Sets",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _logsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final logs = snapshot.data ?? [];

                    if (logs.isEmpty) {
                      return Center(
                        child: Text(
                          "No sets logged yet.\nPlanned sets: $setCap",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(
                              "Set ${log['set_number'] ?? 'N/A'}: ${log['weight'] ?? '0'} lbs × ${log['reps'] ?? '0'} reps",
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () {
                                    _showEditLogDialog(log);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    final logId = log['id'];
                                    if (logId != null) {
                                      _deleteExerciseLog(logId);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Error: Log ID is missing")),
                                      );
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
    );
  }
}
