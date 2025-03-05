import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Provider;

final supabaseProvider = Provider((ref) => Supabase.instance.client);

final organizationProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String?>((ref, orgId) async {
  if (orgId == null) {
    throw Exception("No organization found");
  }

  final supabase = ref.read(supabaseProvider);

  final cache = await ref.cacheFor(const Duration(minutes: 5));

  if (cache.hasValue) {
    return cache.requireValue;
  }

  try {
    final orgResponse = await supabase
        .from('organizations')
        .select('name')
        .eq('id', orgId)
        .single();

    final memberCountResponse = await supabase
        .from('user_organization_membership')
        .select('id', const FetchOptions(count: CountOption.exact))
        .eq('organization_id', orgId);

    final result = {
      'name': orgResponse['name'],
      'memberCount': memberCountResponse.count ?? 0,
    };

    cache.update(result);
    return result;
  } catch (e) {
    throw Exception("Failed to fetch organization: $e");
  }
});
