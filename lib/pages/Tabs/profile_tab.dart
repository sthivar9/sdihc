import 'package:flutter/material.dart';
import 'package:sdihc/auth/authGate.dart';
import 'package:sdihc/pages/functionPages/edit_organize_page.dart';
import 'package:sdihc/pages/functionPages/organization_memberScreen.dart';
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

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      // Fetch profile data
      final profileResponse = await _supabase
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .single();

      // Fetch organization details
      final organizationDetails = await _fetchOrganizationDetails();

      setState(() {
        _profile = profileResponse;
        _classIdController.text = _profile?['class_id']?.toString() ?? '';
        _profile?['organization'] = organizationDetails;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _fetchOrganizationDetails() async {
    try {
      final organizationId = await _getCurrentOrganizationId();
      if (organizationId == null) {
        throw Exception('No organization found for the current user.');
      }

      // Fetch organization name
      final organizationResponse = await Supabase.instance.client
          .from('organizations')
          .select('name')
          .eq('id', organizationId)
          .single()
          .execute();

      if (organizationResponse.status != 200) {
        throw Exception('Failed to fetch organization details: ');
      }

      final organizationName = organizationResponse.data['name'];

      // Fetch member count
      final memberCountResponse = await Supabase.instance.client
          .from('user_organization_membership')
          .select('id', const FetchOptions(count: CountOption.exact))
          .eq('organization_id', organizationId)
          .execute();

      if (memberCountResponse.status != 200) {
        throw Exception('Failed to fetch member count: ');
      }

      final memberCount = memberCountResponse.count ?? 0;

      return {
        'name': organizationName,
        'memberCount': memberCount,
      };
    } catch (e) {
      throw Exception('Error fetching organization details: $e');
    }
  }

  Future<void> _updateClassId() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthGate()),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging out: $error')),
      );
    }
  }

  Widget _buildMemberCountWidget() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people, color: Colors.blue),
          const SizedBox(width: 4),
          Text(
            '${_profile?['organization']['memberCount'] ?? 0} Members',
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _getCurrentOrganizationId() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    final response = await Supabase.instance.client
        .from('user_organization_membership')
        .select('organization_id')
        .eq('user_id', user.id)
        .maybeSingle()
        .execute();

    if (response.status != 200) {
      throw Exception('Failed to fetch organization ID: ');
    }

    return response.data?['organization_id'] as String?;
  }

  Future<int> _getMemberCount(String organizationId) async {
    try {
      final response = await Supabase.instance.client
          .from('user_organization_membership')
          .select('id', const FetchOptions(count: CountOption.exact))
          .eq('organization_id', organizationId)
          .execute();

      if (response.status != 200) {
        throw Exception('Failed to fetch member count: ');
      }

      return response.count ?? 0; // Return the member count or 0 if null
    } catch (e) {
      throw Exception('Error fetching member count: $e');
    }
  }

  Widget _buildOrganizationNameWidget() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchOrganizationDetails(), // Fetch organization details
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator(); // Show loading indicator
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Text(
            'Error: ${snapshot.error ?? "No organization found"}',
            style: const TextStyle(color: Colors.red),
          );
        }

        final organizationName = snapshot.data!['name'];
        final memberCount = snapshot.data!['memberCount'];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Organization Name
              Text(
                organizationName ?? 'No Organization',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(
                  width: 8), // Add spacing between name and member count
              // Member Count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$memberCount Members',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
            onPressed: _logout,
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
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          _buildOrganizationNameWidget(),
                          const SizedBox(width: 16),
                          //_buildMemberCountWidget(),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Buttons for editing and viewing members
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const EditOrganizationPage(),
                                ),
                              );
                            },
                            child: const Text("Edit Organizations"),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const OrganizationMembersScreen(),
                                ),
                              );
                            },
                            child: const Text("See Members"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}
