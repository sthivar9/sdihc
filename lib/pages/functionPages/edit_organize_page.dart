import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditOrganizationPage extends StatefulWidget {
  const EditOrganizationPage({Key? key}) : super(key: key);

  @override
  _EditOrganizationPageState createState() => _EditOrganizationPageState();
}

class _EditOrganizationPageState extends State<EditOrganizationPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _organizations = [];
  bool _isLoading = false;

  final TextEditingController _addMemberEmailController =
      TextEditingController();
  final TextEditingController _joinCodeController = TextEditingController();
  final TextEditingController _newOrgNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchOrganizations();
  }

  @override
  void dispose() {
    _addMemberEmailController.dispose();
    _joinCodeController.dispose();
    _newOrgNameController.dispose();
    super.dispose();
  }

  Future<void> _joinOrganizationWithCode(String joinCode) async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Authentication required');

      // Delete any existing organization membership
      await _supabase
          .from('user_organization_membership')
          .delete()
          .eq('user_id', user.id);

      // Get organization with the join code
      final organization = await _supabase
          .from('organizations')
          .select('id, name')
          .eq('join_code', int.parse(joinCode))
          .single();

      // Add user to the new organization
      await _supabase.from('user_organization_membership').insert({
        'user_id': user.id,
        'organization_id': organization['id'],
        'role': 'member',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Refresh data
      await _fetchOrganizations();
      _showSuccessSnackbar('Joined ${organization['name']} successfully!');
    } catch (e) {
      _showErrorSnackbar('Failed to join organization: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addMemberToOrganization(
      String memberEmail, String organizationId) async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Authentication required');

      final userRole = await _supabase
          .from('user_organization_membership')
          .select('role')
          .eq('user_id', user.id)
          .eq('organization_id', organizationId)
          .single();

      if (!['owner', 'admin'].contains(userRole['role'])) {
        throw Exception('Insufficient permissions');
      }

      final member = await _supabase
          .from('profiles')
          .select('user_id')
          .eq('email', memberEmail)
          .single()
          .timeout(const Duration(seconds: 10));

      final existingMembership = await _supabase
          .from('user_organization_membership')
          .select()
          .eq('user_id', member['user_id'])
          .eq('organization_id', organizationId)
          .maybeSingle();

      if (existingMembership != null) {
        throw Exception('User already in organization');
      }

      await _supabase.from('user_organization_membership').insert({
        'user_id': member['user_id'],
        'organization_id': organizationId,
        'role': 'employee',
      });

      _showSuccessSnackbar('Member added successfully!');
      await _fetchOrganizations();
    } on PostgrestException catch (e) {
      _handleSupabaseError(e, 'User not found');
    } catch (e) {
      _showErrorSnackbar(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addOrganization(String organizationName) async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Authentication required');

      final organizationResponse = await _supabase
          .from('organizations')
          .insert({
            'name': organizationName,
            'owner_id': user.id,
            'join_code': generateJoinCode(),
          })
          .select()
          .single();

      await _supabase.from('user_organization_membership').insert({
        'user_id': user.id,
        'organization_id': organizationResponse['id'],
        'role': 'owner',
      });

      _showSuccessSnackbar('Organization created successfully!');
      await _fetchOrganizations();
    } on PostgrestException catch (e) {
      _handleSupabaseError(e, 'Organization creation failed');
    } catch (e) {
      _showErrorSnackbar(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  int generateJoinCode() {
    final random = Random();
    return random.nextInt(900000) + 100000;
  }

  Future<List<Map<String, dynamic>>> _fetchOrganizationMembers(
      String orgId) async {
    try {
      final response = await _supabase
          .from('user_organization_membership')
          .select('''
            role, 
            profiles:user_id (email, full_name)
          ''')
          .eq('organization_id', orgId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _showErrorSnackbar('Failed to load members');
      return [];
    }
  }

  Future<void> _fetchOrganizations() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Authentication required');
      }

      // Get user's organization memberships
      final memberships = await _supabase
          .from('user_organization_membership')
          .select('organization_id')
          .eq('user_id', user.id)
          .timeout(const Duration(seconds: 5));

      if (memberships.isEmpty) {
        setState(() => _organizations = []);
        return;
      }

      // Extract organization IDs from memberships
      final orgIds =
          memberships.map((m) => m['organization_id'] as String).toList();

      // Fetch organizations the user is part of
      final response = await _supabase
          .from('organizations')
          .select('id, name, join_code, created_at')
          .in_('id', orgIds)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 10));

      setState(() {
        _organizations = List<Map<String, dynamic>>.from(response);
      });
    } on PostgrestException catch (e) {
      _handleSupabaseError(e, 'Failed to load organizations');
    } catch (e) {
      _showErrorSnackbar(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleSupabaseError(PostgrestException e, String fallbackMessage) {
    final message = e.details ?? e.message ?? fallbackMessage;
    _showErrorSnackbar(message);
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAddMemberDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Member'),
        content: TextField(
          controller: _addMemberEmailController,
          decoration: const InputDecoration(
            labelText: 'Member Email',
            hintText: 'name@example.com',
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_organizations.isEmpty) return;
              final orgId = _organizations.first['id'];
              await _addMemberToOrganization(
                  _addMemberEmailController.text, orgId.toString());
              Navigator.pop(context);
            },
            child: const Text('Add Member'),
          ),
        ],
      ),
    );
  }

  void _showJoinOrganizationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Organization'),
        content: TextField(
          controller: _joinCodeController,
          decoration: const InputDecoration(
            labelText: '6-digit Code',
            hintText: '123456',
          ),
          keyboardType: TextInputType.number,
          maxLength: 6,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _joinOrganizationWithCode(_joinCodeController.text);
              Navigator.pop(context);
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void _showAddOrganizationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Organization'),
        content: TextField(
          controller: _newOrgNameController,
          decoration: const InputDecoration(
            labelText: 'Organization Name',
            hintText: 'My Awesome Team',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _addOrganization(_newOrgNameController.text);
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Organizations'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: CircularProgressIndicator(),
            )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Wrap(
                spacing: 12,
                children: [
                  _ActionButton(
                    icon: Icons.person_add,
                    label: 'Add Member',
                    onPressed: _showAddMemberDialog,
                  ),
                  _ActionButton(
                    icon: Icons.group_add,
                    label: 'Join Org',
                    onPressed: _showJoinOrganizationDialog,
                  ),
                  _ActionButton(
                    icon: Icons.business,
                    label: 'New Org',
                    onPressed: _showAddOrganizationDialog,
                  ),
                ],
              ),
            ), /*
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _fetchOrganizations,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _organizations.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final org = _organizations[index];
                          return ListTile(
                            title: Text(org['name'] ?? 'Unnamed Organization'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Code: ${org['join_code'] ?? 'N/A'}'),
                                Text(
                                    'Created: ${_formatDate(org['created_at'])}'),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                          );
                        },
                      ),
                    ),
            ),*/
            //ElevatedButton(onPressed: () {}, child: Text("see members")),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    final date = DateTime.parse(timestamp.toString());
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 20),
      label: Text(label),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
