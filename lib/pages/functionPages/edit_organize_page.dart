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
  final _organizationNameController = TextEditingController();
  bool _isLoading = false;
  bool _loading = false;
  String? _error;

  final TextEditingController _addMemberEmailController =
      TextEditingController();
  final TextEditingController _joinCodeController = TextEditingController();
  final TextEditingController _newOrgNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchOrganizations();
    _fetchOrganizationName();
  }

  @override
  void dispose() {
    _addMemberEmailController.dispose();
    _joinCodeController.dispose();
    _newOrgNameController.dispose();
    _organizationNameController.dispose();
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

  Future<void> _fetchOrganizationName() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      // Fetch the organization name
      final response = await _supabase
          .from('organizations')
          .select('name')
          .eq('owner_id', userId)
          .single()
          .execute();

      if (response.status != 200) {
        throw Exception('Failed to fetch organization name: ');
      }

      final organizationName = response.data['name'];
      _organizationNameController.text = organizationName;

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _updateOrganizationName() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      final newName = _organizationNameController.text.trim();
      if (newName.isEmpty) {
        throw Exception('Organization name cannot be empty');
      }

      // Update the organization name
      final response = await _supabase
          .from('organizations')
          .update({'name': newName})
          .eq('owner_id', userId)
          .execute();

      if (response.status != 200) {
        throw Exception('Failed to update organization name: ');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Organization name updated successfully!')),
      );

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating organization name: $_error')),
      );
    }
  }

  int generateJoinCode() {
    final random = Random();
    return random.nextInt(900000) + 100000;
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

  Future<String?> fetchOrganizationJoinCode(String organizationId) async {
    try {
      final response = await _supabase
          .from('organizations')
          .select('join_code')
          .eq('id', organizationId)
          .single();

      print('Join Code Response: $response'); // Debugging

      // Extract join_code and convert it to a String
      final joinCode = response['join_code'];
      return joinCode?.toString(); // Convert to String if not null
    } catch (e) {
      print('Error fetching join code: $e'); // Debugging
      return null;
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

  void _showJoinCodeDialog(String organizationId) async {
    final joinCode = await fetchOrganizationJoinCode(organizationId);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Organization Join Code'),
        content: Text(
          joinCode ?? 'No join code found for this organization.',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
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
                  _ActionButton(
                    icon: Icons.code,
                    label: 'Show Join Code',
                    onPressed: () {
                      if (_organizations.isNotEmpty) {
                        _showJoinCodeDialog(_organizations.first['id']);
                      }
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Organization Name Text Field
                  TextField(
                    controller: _organizationNameController,
                    decoration: const InputDecoration(
                      labelText: 'Organization Name',
                      hintText: 'Enter new organization name',
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Save Button
                  ElevatedButton(
                    onPressed: _updateOrganizationName,
                    child: const Text('Save Changes'),
                  ),
                ],
              ),
            ),
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
