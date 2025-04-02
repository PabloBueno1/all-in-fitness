import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/colors.dart';

class WorkoutRecommendationsCard extends StatefulWidget {
  const WorkoutRecommendationsCard({Key? key}) : super(key: key);

  @override
  _WorkoutRecommendationsCardState createState() => _WorkoutRecommendationsCardState();
}

class _WorkoutRecommendationsCardState extends State<WorkoutRecommendationsCard> {
  bool _isExpanded = false;
  bool _isLoading = false;
  Map<String, dynamic>? _recommendations;

  Future<void> _fetchRecommendations() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in to get recommendations')),
          );
        }
        return;
      }

      final response = await http.get(
        Uri.parse('http://localhost:8000/workouts/recommendations'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null) {
          setState(() {
            _recommendations = data['data'];
            _isExpanded = true;  // Auto-expand when we get new recommendations
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid response format')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to fetch recommendations')),
          );
        }
      }
    } catch (e) {
      print('Error fetching recommendations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error fetching recommendations')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildGenerateButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Get personalized workout recommendations based on your fitness level and history.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          CupertinoButton(
            color: kPrimaryBlue,
            borderRadius: BorderRadius.circular(8),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.sparkles, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Generate AI Recommendations',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            onPressed: _fetchRecommendations,
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseRow(Map<String, dynamic> exercise) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  exercise['name'],
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kPrimaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${exercise['sets']} sets',
                  style: TextStyle(
                    fontSize: 13,
                    color: kPrimaryBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(CupertinoIcons.repeat, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                exercise['reps'],
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 16),
              Icon(CupertinoIcons.timer, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                'Rest: ${exercise['rest_seconds']}s',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          if (exercise['notes'] != null) ...[
            const SizedBox(height: 8),
            Text(
              exercise['notes'],
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          CupertinoListTile(
            title: Row(
              children: [
                const Text(
                  'Workout Recommendations',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_isLoading)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CupertinoActivityIndicator(),
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_recommendations != null && !_isLoading)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Icon(
                      CupertinoIcons.refresh,
                      color: kPrimaryBlue,
                    ),
                    onPressed: _fetchRecommendations,
                  ),
                if (_recommendations != null)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Icon(
                      _isExpanded
                          ? CupertinoIcons.chevron_up
                          : CupertinoIcons.chevron_down,
                      color: kPrimaryBlue,
                    ),
                    onPressed: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                  ),
              ],
            ),
          ),

          // Content
          if (_recommendations == null && !_isLoading)
            _buildGenerateButton()
          else if (_isExpanded && _recommendations != null) ...[
            const Divider(),
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Workout Info
                      Text(
                        _recommendations?['workout_name']?.toString() ?? 'Custom Workout',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(CupertinoIcons.timer, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${_recommendations?['estimated_duration_minutes']?.toString() ?? '45'} minutes',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(CupertinoIcons.gauge, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            _recommendations?['difficulty_level']?.toString() ?? 'Intermediate',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: kPrimaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          (_recommendations?['target_muscles'] as List? ?? ['Full Body']).join(" • "),
                          style: TextStyle(
                            fontSize: 13,
                            color: kPrimaryBlue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Warmup Section
                      const Text(
                        'Warmup',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...((_recommendations?['warmup'] as List?) ?? ['Dynamic stretching', 'Light cardio']).map((w) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      Icon(CupertinoIcons.circle_fill, size: 6, color: Colors.grey[400]),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          w.toString(),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Main Exercises Section
                      const Text(
                        'Main Exercises',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...((_recommendations?['exercises'] as List?) ?? []).map((e) => _buildExerciseRow(e as Map<String, dynamic>)),

                      // Cooldown Section
                      const SizedBox(height: 16),
                      const Text(
                        'Cooldown',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...((_recommendations?['cooldown'] as List?) ?? ['Light stretching', 'Deep breathing']).map((c) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      Icon(CupertinoIcons.circle_fill, size: 6, color: Colors.grey[400]),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          c.toString(),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
} 