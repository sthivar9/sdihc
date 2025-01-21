import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _profile;
  final _classIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _classIdController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      // Get current user
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Not authenticated');
      }

      // Fetch profile data
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .single();

      setState(() {
        _profile = response;
        _classIdController.text = response['class_id']?.toString() ?? '';
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _updateClassId() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Not authenticated');
      }

      // Update class_id
      await _supabase.from('profiles').update({
        'class_id': _classIdController.text,
      }).eq('user_id', userId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );

      await _loadProfile(); // Reload profile data
    } catch (error) {
      setState(() {
        _error = error.toString();
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $_error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Email display
                      Text(
                        'Email:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(_supabase.auth.currentUser?.email ?? 'No email'),
                      const SizedBox(height: 24),

                      // Class ID field
                      Text(
                        'Class ID:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _classIdController,
                              decoration: const InputDecoration(
                                hintText: 'Enter class ID',
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: _updateClassId,
                            child: const Text('Update Class'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}
