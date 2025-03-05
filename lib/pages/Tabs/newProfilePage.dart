import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sdihc/auth/authGate.dart';
import 'package:sdihc/pages/functionPages/edit_organize_page.dart';
import 'package:sdihc/pages/functionPages/organization_memberScreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Provider;

// Define a Supabase client provider
final supabaseClientProvider = Provider((ref) => Supabase.instance.client);

// Profile data provider
final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier(ref.watch(supabaseClientProvider));
});

class ProfileState {
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? profile;

  ProfileState({
    this.isLoading = true,
    this.error,
    this.profile,
  });

  ProfileState copyWith({
    bool? isLoading,
    String? error,
    Map<String, dynamic>? profile,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      profile: profile ?? this.profile,
    );
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final SupabaseClient _supabase;

  ProfileNotifier(this._supabase) : super(ProfileState()) {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      final profileResponse = await _supabase
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .single();

      final organizationDetails = await _fetchOrganizationDetails();

      state = state.copyWith(
        profile: {
          ...profileResponse,
          'organization': organizationDetails,
        },
        isLoading: false,
      );
    } catch (error) {
      state = state.copyWith(
        error: error.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> updateClassId(String classId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      await _supabase.from('profiles').update({
        'class_id': classId,
      }).eq('user_id', userId);

      await _loadProfile();
    } catch (error) {
      state = state.copyWith(
        error: error.toString(),
        isLoading: false,
      );
    }
  }

  Future<Map<String, dynamic>> _fetchOrganizationDetails() async {
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

  Future<void> logout(BuildContext context) async {
    await _supabase.auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthGate()),
    );
  }
}

// Wrap your widget with ProviderScope
class NewProfilePage extends ConsumerWidget {
  const NewProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.png'),
            fit: BoxFit.fill,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOrganizationCard(ref),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white54,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        if (profileState.isLoading)
                          const Center(child: CircularProgressIndicator())
                        else if (profileState.error != null)
                          Text(
                            'Error: ${profileState.error}',
                            style: const TextStyle(color: Colors.red),
                          )
                        else
                          Text(
                            'Hi! ${profileState.profile?['full_name'] ?? 'No name'}',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 30,
                            ),
                          ),
                        const SizedBox(height: 20),
                        _buildActionButtons(context, ref),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizationCard(WidgetRef ref) {
    final profileState = ref.watch(profileProvider);

    if (profileState.isLoading) {
      return const CircularProgressIndicator();
    }

    if (profileState.error != null || profileState.profile == null) {
      return Text(
        'Error: ${profileState.error ?? "No organization found"}',
        style: const TextStyle(color: Colors.red),
      );
    }

    final organization = profileState.profile!['organization'] ?? {};
    final organizationName = organization['name'] ?? 'No Organization';
    final memberCount = organization['memberCount'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Welcome to",
          style: TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.normal,
          ),
        ),
        Text(
          '$organizationName\'s Organization',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 35,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Text(
          "Management",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  ref.context,
                  MaterialPageRoute(
                    builder: (context) => const OrganizationMembersScreen(),
                  ),
                );
              },
              child: Row(
                children: [
                  const Icon(Icons.people, color: Colors.black54),
                  const SizedBox(width: 4),
                  Text(
                    '$memberCount Members',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    final profileNotifier = ref.read(profileProvider.notifier);
    final classIdController = TextEditingController(
      text: ref.watch(profileProvider).profile?['class_id']?.toString() ?? '',
    );

    return Row(
      children: [
        Flexible(
          flex: 1,
          fit: FlexFit.loose,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EditOrganizationPage(),
                  ),
                );
              },
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: Colors.black54.withOpacity(.1),
                ),
                child: const Center(
                  child: Text(
                    'Edit organization',
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
              ),
            ),
          ),
        ),
        Flexible(
          flex: 1,
          fit: FlexFit.loose,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Update Class ID'),
                      content: TextField(
                        controller: classIdController,
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
                            profileNotifier
                                .updateClassId(classIdController.text);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Class ID updated successfully!')),
                            );
                          },
                          child: const Text('Update'),
                        ),
                      ],
                    );
                  },
                );
              },
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: Colors.black54.withOpacity(.1),
                ),
                child: const Center(
                  child: Text(
                    'Class ID',
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
