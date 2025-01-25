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

  @override
  void initState() {
    super.initState();
    _membersFuture = _retrieveAllMembersOfJoinedOrganizations();
  }

  Future<List<Map<String, dynamic>>> _retrieveAllMembersOfJoinedOrganizations() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null || user.id.isEmpty) {
        throw Exception('User not authenticated');
      }

      final organizationsResponse = await _supabase
          .from('user_organization_membership')
          .select('organization_id')
          .eq('user_id', user.id);

      if (organizationsResponse.isEmpty) {
        return [];
      }

      final orgIds = (organizationsResponse as List).map((org) => org['organization_id'].toString()).toList();

      final membersResponse = await _supabase
          .from('user_organization_membership')
          .select('''
            organization_id,
            role,
            user_id,
            profiles:user_id (full_name)
          ''')
          .in_('organization_id', orgIds);

      return List<Map<String, dynamic>>.from(membersResponse).map((member) {
        final profile = (member['profiles'] as Map?) ?? {};
        
        return {
          'org_id': member['organization_id']?.toString() ?? 'N/A',
          'user_id': member['user_id']?.toString() ?? 'N/A',
          'role': (member['role']?.toString() ?? 'member').toUpperCase(),
          'full_name': profile['full_name']?.toString() ?? 'Unknown Member',
        };
      }).toList();
    } catch (e, stack) {
      debugPrint('Error fetching members: $e\n$stack');
      throw Exception('Failed to load members');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organization Members'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _membersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(color: Colors.red[800], fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final members = snapshot.data ?? [];

          if (members.isEmpty) {
            return const Center(
              child: Text('No members found in your organizations'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final member = members[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    member['full_name'].toString().isNotEmpty 
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
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}