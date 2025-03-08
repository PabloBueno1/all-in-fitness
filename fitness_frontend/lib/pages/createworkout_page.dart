import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CreateWorkoutPage extends StatefulWidget {
  @override
  _CreateWorkoutPageState createState() => _CreateWorkoutPageState();
}

class _CreateWorkoutPageState extends State<CreateWorkoutPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  Future<void> _createWorkout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final Map<String, dynamic> payload = {
      "name": _nameController.text,
      "duration": int.tryParse(_durationController.text) ?? 0,
      "date": _selectedDate.toIso8601String()
    };

    final response = await http.post(
      Uri.parse('http://localhost:8000/workouts'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(payload),
    );

    if (response.statusCode == 200) {
      Navigator.pop(context, true); // ✅ Return to previous page & refresh
    } else {
      print("Failed to create workout: ${response.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Workout")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Workout Name"),
            ),
            TextField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Duration (minutes)"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (pickedDate != null) {
                  setState(() {
                    _selectedDate = pickedDate;
                  });
                }
              },
              child: Text("Select Date: ${_selectedDate.toLocal()}".split(' ')[0]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _createWorkout,
              child: const Text("Create Workout"),
            ),
          ],
        ),
      ),
    );
  }
}
