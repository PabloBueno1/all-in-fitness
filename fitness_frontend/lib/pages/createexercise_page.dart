import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CreateExercisePage extends StatefulWidget {
  @override
  _CreateExercisePageState createState() => _CreateExercisePageState();
}

class _CreateExercisePageState extends State<CreateExercisePage> {
  final TextEditingController _nameController = TextEditingController();
  String? _errorMessage; // ✅ Store error messages

  Future<void> _createExercise() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final Map<String, dynamic> payload = {
      "name": _nameController.text.trim(),
      "is_predefined": true, // ✅ Always true when created from frontend
    };

    final response = await http.post(
      Uri.parse('http://localhost:8000/exercise_types'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(payload),
    );

    if (response.statusCode == 200) {
      Navigator.pop(context, true); // ✅ Return to previous page & refresh
    } else {
      setState(() {
        _errorMessage = json.decode(response.body)['detail']; // ✅ Display error
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Exercise")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ),

            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Exercise Name"),
            ),

            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _createExercise,
              child: const Text("Create Exercise"),
            ),
          ],
        ),
      ),
    );
  }
}
