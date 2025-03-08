import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:dropdown_search/dropdown_search.dart';
import 'dart:convert';

class WorkoutsPage extends StatefulWidget {
  const WorkoutsPage({super.key});

  @override
  _WorkoutsPageState createState() => _WorkoutsPageState();
}

class _WorkoutsPageState extends State<WorkoutsPage> {
  List workouts = [];
  List<Map<String, dynamic>> exerciseTypes = [];
  Map<int, List> workoutExercises = {}; // Stores exercises for each workout
  Map<int, int?> selectedExercise = {}; // Stores selected exercise per workout
  final TextEditingController _setsController = TextEditingController(); // Stores set count

  @override
  void initState() {
    super.initState();
    _fetchWorkouts();
    _fetchExerciseTypes();
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
        workouts = decodedResponse;
      });

      for (var workout in workouts) {
        _fetchWorkoutExercises(workout['id']);
      }
    }
  }

  /// Delete Workout
  Future<void> _deleteWorkout(int workoutId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final response = await http.delete(
      Uri.parse('http://localhost:8000/workouts/$workoutId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      setState(() {
        workouts.removeWhere((workout) => workout['id'] == workoutId);
      });
    } else {
      print("Failed to delete workout: ${response.body}");
    }
  }



  /// Fetch available exercise types
  Future<void> _fetchExerciseTypes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final response = await http.get(
      Uri.parse('http://localhost:8000/exercise_types'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      setState(() {
        exerciseTypes = (json.decode(response.body) as List).cast<Map<String, dynamic>>();
      });
    }
  }

  /// Fetch exercises associated with a specific workout
  Future<void> _fetchWorkoutExercises(int workoutId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final response = await http.get(
      Uri.parse('http://localhost:8000/exercises/$workoutId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      List decodedResponse = json.decode(response.body) ?? [];
      setState(() {
        workoutExercises[workoutId] = decodedResponse;
      });
    }
    else {
    setState(() {
      workoutExercises[workoutId] = [];
    });
    }
  }

  /// Add an exercise to a workout with a specified number of sets
  Future<void> _addExerciseToWorkout(int workoutId, int exerciseId, int sets) async {
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
        "exercise_id": exerciseId,
        "sets": sets,  // Send sets as an integer
      }),
    );

    if (response.statusCode == 200) {
      _fetchWorkoutExercises(workoutId);
      setState(() {
        selectedExercise[workoutId] = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Exercise added successfully!")),
      );
    } else {
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
      setState(() {
        workoutExercises[workoutId]!.removeWhere((exercise) => exercise['exercise_id'] == exerciseId);
      });
    } else {
      print("Failed to remove exercise: ${response.body}");
    }
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text("Workouts")),
    body: Column(
      children: [
        const SizedBox(height: 20),
        const Text("Your Workouts:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

        // Buttons for Creating Workout & Adding Exercise
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.pushNamed(context, '/create-workout');
                  if (result == true) {
                    setState(() {
                      _fetchWorkouts(); // ✅ Refresh workouts after returning
                    });
                  }
                },
                child: const Text("Create Workout"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.pushNamed(context, '/create-exercise');
                  if (result == true) {
                    setState(() {
                      _fetchExerciseTypes(); // ✅ Refresh exercise list after returning
                    });
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
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteWorkout(workoutId),
                      ),
                    ],
                  ),
                  subtitle: Text("Date: ${workout['date']} | Duration: ${workout['duration']} min"),
                  children: [
                    // Dropdown + Add Button for Adding Exercise
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          DropdownSearch<Map<String, dynamic>>(
                              popupProps: const PopupProps.menu(
                                showSearchBox: true,
                                searchFieldProps: TextFieldProps(
                                  decoration: InputDecoration(labelText: 'Search Exercise'),
                                ),
                              ),
                              itemAsString: (item) => item['name'] ?? '',
                              items: exerciseTypes,
                              dropdownDecoratorProps: const DropDownDecoratorProps(
                                dropdownSearchDecoration: InputDecoration(
                                  labelText: "Select Exercise",
                                ),
                              ),
                              selectedItem: exerciseTypes.firstWhere(
                                (ex) => ex['id'] == selectedExercise[workoutId],
                                orElse: () => {},
                              ),
                              onChanged: (selected) {
                                setState(() {
                                  selectedExercise[workoutId] = selected?['id'];
                                });
                              },
                            ),

                          TextField(
                            controller: _setsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "Number of Sets"),
                            onChanged: (text) {
                              setState(() {}); // 🔹 Forces UI to update when user types a number
                            },
                          ),

                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.blue),
                            onPressed: (selectedExercise[workoutId] != null && 
                                        _setsController.text.isNotEmpty && 
                                        int.tryParse(_setsController.text) != null)
                                ? () {
                                    int sets = int.parse(_setsController.text);
                                    _addExerciseToWorkout(workoutId, selectedExercise[workoutId]!, sets);
                                  }
                                : null, // 🔹 Button is disabled if conditions are not met
                          ),
                        ],
                      ),
                    ),

                    // Display added exercises
                    if (workoutExercises.containsKey(workoutId) && workoutExercises[workoutId]!.isNotEmpty)
                      Column(
                        children: workoutExercises[workoutId]!.map<Widget>((exercise) {
                          return ListTile(
                            title: Text(exercise['exercise_name']),
                            subtitle: Text("Sets: ${exercise['sets']}"),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => _removeExerciseFromWorkout(workoutId, exercise['exercise_id']),
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
                                setState(() {
                                  _fetchWorkoutExercises(workoutId);
                                });
                              }
                            },
                          );
                        }).toList(),
                      )
                    else
                      const Text("No exercises added yet"),
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