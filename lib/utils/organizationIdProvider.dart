import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// StateProvider to store the cached organization ID
final cachedOrganizationIdProvider = StateProvider<String?>((ref) => null);

// FutureProvider to fetch organization ID only if not cached
final organizationIdProvider = FutureProvider<String?>((ref) async {
  final cachedId = ref.read(cachedOrganizationIdProvider);
  if (cachedId != null) {
    return cachedId; // Return cached ID if available
  }

  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;

  final response = await Supabase.instance.client
      .from('user_organization_membership')
      .select('organization_id')
      .eq('user_id', user.id)
      .maybeSingle()
      .execute();

  if (response.status != 200) {
    throw Exception('Failed to fetch organization ID: HTTP ${response.status}');
  }

  final orgId = response.data?['organization_id'] as String?;

  // Cache the ID so it's not fetched again
  ref.read(cachedOrganizationIdProvider.notifier).state = orgId;

  return orgId;
});
