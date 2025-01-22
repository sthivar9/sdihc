import 'package:flutter/material.dart';
import 'package:sdihc/auth/authGate.dart';
import 'package:sdihc/pages/functionPages/edit_organize_page.dart';
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
      final profileResponse = await _supabase
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .single();

      // Fetch organization details
      final organizationResponse = await _supabase
          .from('organizations')
          .select('name, id')
          .eq('owner_id', userId)
          .single()
          .execute();

      Map<String, dynamic> orgDetails = {};
      if (organizationResponse.status == 200) {
        orgDetails = organizationResponse.data;
      }

      // Fetch member count
      final memberCountResponse = await _supabase
          .from('user_organization_membership')
          .select('id', const FetchOptions(count: CountOption.exact))
          .eq('organization_id', orgDetails['id'])
          .execute();

      int memberCount = 0; // Initialize with a default value
      if (memberCountResponse.status == 200) {
        memberCount = memberCountResponse.count ?? 0; // Use null-aware operator
      }

      setState(() {
        _profile = profileResponse;
        _classIdController.text = _profile!['class_id']?.toString() ?? '';
        _profile!['organization'] = {
          'name': orgDetails['name'],
          'memberCount': memberCount
        };
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

  Future<void> _logout() async {
    try {
      await _supabase.auth.signOut();
      // Navigate back to login or splash screen after logout
      Navigator.push(
          context, MaterialPageRoute(builder: (context) => const AuthGate()));
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging out: $error')),
      );
    }
  }

  Widget _buildMemberCountWidget() {
    return Container(
      padding: EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people, color: Colors.blue),
          SizedBox(width: 4),
          Text(
            '${_profile?['organization']['memberCount'] ?? 0} Members',
            style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizationNameWidget() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Text(
        _profile?['organization']['name'] ?? 'No Organization',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(),
          ),
        ],
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

                      const SizedBox(height: 24),

                      // Organization Details
                      Text(
                        'Organization:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          _buildOrganizationNameWidget(),
                          SizedBox(width: 20),
                          _buildMemberCountWidget(),
                        ],
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const EditOrganizationPage()),
                            );
                          },
                          child: Text("Edit Organizations"))
                    ],
                  ),
                ),
    );
  }
}
