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

      final profileResponse = await _supabase
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .single();

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

      final organizationResponse = await _supabase
          .from('organizations')
          .select('name')
          .eq('id', organizationId)
          .single();

      final memberCountResponse = await _supabase
          .from('user_organization_membership')
          .select('id', const FetchOptions(count: CountOption.exact))
          .eq('organization_id', organizationId);

      return {
        'name': organizationResponse['name'],
        'memberCount': memberCountResponse.count ?? 0,
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
        const SnackBar(content: Text('Class ID updated successfully!')),
      );

      await _loadProfile();
    } catch (error) {
      setState(() {
        _error = error.toString();
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating Class ID: $_error')),
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

  Future<String?> _getCurrentOrganizationId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final response = await _supabase
        .from('user_organization_membership')
        .select('organization_id')
        .eq('user_id', user.id)
        .maybeSingle();

    return response['organization_id'] as String?;
  }

  Widget _buildOrganizationCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchOrganizationDetails(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Text(
            'Error: ${snapshot.error ?? "No organization found"}',
            style: const TextStyle(color: Colors.red),
          );
        }

        final organizationName = snapshot.data!['name'];
        final memberCount = snapshot.data!['memberCount'];

        return Card(
          elevation: 4,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OrganizationMembersScreen(),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Organization',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.deepPurple),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const EditOrganizationPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    organizationName ?? 'No Organization',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.people, color: Colors.deepPurple),
                      const SizedBox(width: 4),
                      Text(
                        '$memberCount Members',
                        style: const TextStyle(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildClassIdCard() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Update Class ID'),
                content: TextField(
                  controller: _classIdController,
                  decoration: const InputDecoration(
                    hintText: 'Enter Class ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      _updateClassId();
                      Navigator.pop(context);
                    },
                    child: const Text('Update'),
                  ),
                ],
              );
            },
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Class ID',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                _profile?['class_id']?.toString() ?? 'Not Set',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.deepOrange,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        elevation: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Email',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: Colors.deepPurple,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _supabase.auth.currentUser?.email ?? 'No email',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _buildClassIdCard(),
                      _buildOrganizationCard(),
                    ],
                  ),
                ),
    );
  }
}
