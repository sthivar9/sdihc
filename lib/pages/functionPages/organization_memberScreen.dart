import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrganizationMembersScreen extends StatefulWidget {
  const OrganizationMembersScreen({super.key});

  @override
  State<OrganizationMembersScreen> createState() => _OrganizationMembersScreenState();
}

class _OrganizationMembersScreenState extends State<OrganizationMembersScreen> {
  final _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _membersFuture;
  Map<String, dynamic>? _currentOrganization;
  bool _isLoading = false;
  bool _hasOrganization = false;

  @override
  void initState() {
    super.initState();
    _membersFuture = _initializeData();
  }

  Future<List<Map<String, dynamic>>> _initializeData() async {
    try {
    // Get all organization memberships
    final orgResponse = await _supabase
        .from('user_organization_membership')
        .select('organizations!inner(*)')
        .order('created_at', ascending: false); // Get most recent first

    if (orgResponse.isNotEmpty) {
      setState(() {
        _currentOrganization = orgResponse.first['organizations'] as Map<String, dynamic>;
        _hasOrganization = true;
      });
    }

    return _hasOrganization ? _loadMembers() : [];
  } catch (e) {
    debugPrint('Initialization error: $e');
    return [];
  }
}

  Future<List<Map<String, dynamic>>> _loadMembers() async {
    try {
      final response = await _supabase
          .from('user_organization_membership')
          .select('''
            role, 
            user_id,
            profiles!fk_user_profile (full_name) // Use your actual FK name
          ''')
          .eq('organization_id', _currentOrganization!['id']);

      return List<Map<String, dynamic>>.from(response).map((member) {
        final profile = member['profiles'] as Map<String, dynamic>?;
        return {
          'full_name': profile?['full_name']?.toString() ?? 'New Member',
          'role': (member['role']?.toString() ?? 'member').toUpperCase(),
          'user_id': member['user_id']?.toString() ?? 'N/A',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error loading members: $e');
      return [];
    }
  }

  Future<void> _leaveOrganization() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase
          .from('user_organization_membership')
          .delete()
          .eq('user_id', user.id);

      setState(() {
        _hasOrganization = false;
        _currentOrganization = null;
      });
      _membersFuture = Future.value([]);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Left organization successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error leaving: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organization Members'),
        actions: [
          if (_hasOrganization)
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: _isLoading ? null : _leaveOrganization,
              tooltip: 'Leave Organization',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _membersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
        final error = snapshot.error.toString();
        if (error.contains('multiple rows')) {
          return _buildMultipleOrganizationsError();
        }
        return _buildErrorState(error);
      }

        if (!_hasOrganization) {
          return _buildJoinPrompt();
        }

        final members = snapshot.data ?? [];
        return members.isEmpty 
            ? _buildEmptyMembersState()
            : _buildMembersList(members);
      },
    );
  }

  
Widget _buildMultipleOrganizationsError() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.warning, size: 40, color: Colors.orange),
        const SizedBox(height: 16),
        const Text(
          'Multiple organizations found!',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Please contact support',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {},
          child: const Text('Contact Support'),
        ),
      ],
    ),
  );
}

  Widget _buildMembersList(List<Map<String, dynamic>> members) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue[100],
              child: Text(
                member['full_name'].isNotEmpty 
                    ? member['full_name'][0].toUpperCase()
                    : '?',
                style: const TextStyle(color: Colors.blue),
              ),
            ),
            title: Text(
              member['full_name'],
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text('Role: ${member['role']}'),
            trailing: Text(
              'ID: ${member['user_id'].substring(0, 6)}...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildJoinPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.group_add, size: 40, color: Colors.grey),
          const SizedBox(height: 20),
          const Text('You are not part of any organization'),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _showJoinDialog(),
            child: const Text('Join Organization'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMembersState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.group_off, size: 40, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No members found in ${_currentOrganization?['name'] ?? 'the organization'}',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 40, color: Colors.red),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Error: $error',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

    void _showJoinDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final _joinCodeController = TextEditingController();
        return AlertDialog(
          title: const Text('Join Organization'),
          content: TextField(
            controller: _joinCodeController,
            decoration: const InputDecoration(hintText: "Enter Join Code"),
            keyboardType: TextInputType.number,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Join'),
              onPressed: () async {
                if (_joinCodeController.text.length == 6) {
                  try {
                    final userId = _supabase.auth.currentUser?.id;
                    if (userId == null) throw Exception('Not authenticated');

                    final response = await _supabase
                        .from('organizations')
                        .select('id')
                        .eq('join_code', int.parse(_joinCodeController.text))
                        .single();

                    await _supabase.from('user_organization_membership').insert({
                      'user_id': userId,
                      'organization_id': response['id'],
                      'role': 'employee',
                    });

                    setState(() {
                      _hasOrganization = true;
                      _currentOrganization = response;
                      _membersFuture = _loadMembers();
                    });
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Joined organization successfully!')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error joining: $e')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid 6-digit code')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}