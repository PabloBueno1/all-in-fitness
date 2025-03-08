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
  late Future<List<Map<String, dynamic>>> _logsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    workoutId = args['workoutId'];
    exerciseId = args['exerciseId'];
    exerciseName = args['exerciseName'];
    setCap = args['setCap'];
    _logsFuture = _fetchExerciseLogs(workoutId,exerciseId);
  }

  // Fetch Exercise Logs for a Workout & Exercise
  Future<List<Map<String, dynamic>>> _fetchExerciseLogs(int workoutId, int exerciseId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final response = await http.get(
      Uri.parse('http://localhost:8000/exercise_log/$workoutId/$exerciseId'),
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
        const SnackBar(content: Text("You’ve reached the maximum number of sets.")),
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
      Uri.parse('http://localhost:8000/exercise_log'),
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
      Uri.parse('http://localhost:8000/exercise_log/$logId'),  // Only log_id is needed
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
  Future<void> _editExerciseLog(int logId, int initialWeight, int initialReps) async {
    final TextEditingController weightController = TextEditingController(text: initialWeight.toString());
    final TextEditingController repsController = TextEditingController(text: initialReps.toString());

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Set'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Weight (lbs)"),
            ),
            TextField(
              controller: repsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Reps"),
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
                Uri.parse('http://localhost:8000/exercise_log/$logId'),
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

@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(exerciseName)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Log New Set", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            TextField(
              controller: _weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Weight (lbs)"),
            ),
            TextField(
              controller: _repsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Reps"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _logSingleExerciseSet(workoutId, exerciseId),
              child: const Text("Log Set"),
            ),
            const SizedBox(height: 20),
            const Text("Logged Sets", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _logsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final logs = snapshot.data ?? [];

                  if (logs.isEmpty) {
                    return const Center(child: Text("No sets logged yet."));
                  }

                  return ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return ListTile(
                        title: Text("Set ${log['set_number'] ?? 'N/A'}: ${log['weight'] ?? '0'} lbs x ${log['reps'] ?? '0'} reps"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                _editExerciseLog(log['id'], log['weight'], log['reps']);
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
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
