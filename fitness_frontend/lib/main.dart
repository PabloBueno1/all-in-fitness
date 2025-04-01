import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/signup_page.dart';
import 'pages/meals_page.dart';
import 'pages/workouts_page.dart';
import 'pages/createfood_page.dart';
import 'pages/createmeal_page.dart';
import 'pages/createworkout_page.dart';
import 'pages/createexercise_page.dart';
import 'pages/exerciselog_page.dart';
import 'pages/fooddetail_page.dart';
import 'pages/goals_page.dart';
import 'pages/creategoal_page.dart';
import 'pages/profile_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fitness App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/goals': (context) => const GoalsPage(),
        '/create-goal': (context) => const CreateGoalPage(),
        '/signup': (context) => SignUpPage(),
        '/meals': (context) => const MealsPage(),
        '/workouts': (context) => const WorkoutsPage(),
        '/create-meal': (context) => const CreateMealPage(),
        '/add-food': (context) => const CreateFoodPage(),
        '/create-workout': (context) => CreateWorkoutPage(),
        '/create-exercise': (context) => CreateExercisePage(),
        '/exercise-log': (context) => const ExerciseLogPage(),
        '/food-details': (context) => const FoodDetailsPage(),
        '/profile': (context) => const ProfilePage(),
      },
    );
  }
}
