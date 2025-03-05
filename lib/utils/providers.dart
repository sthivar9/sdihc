import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sdihc/utils/organizationIdProvider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final past7DaysDataProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final orgId = await ref.watch(organizationIdProvider.future);

  if (orgId == null) {
    throw Exception('No organization found for the current user.');
  }

  final today = DateTime.now();
  final sevenDaysAgo = today.subtract(Duration(days: 7));

  // Format dates properly for Supabase
  final String todayStr = DateFormat('yyyy-MM-dd').format(today);
  final String sevenDaysAgoStr = DateFormat('yyyy-MM-dd').format(sevenDaysAgo);

  final response = await Supabase.instance.client
      .from('daily_stats')
      .select('date, total_selling_price')
      .eq('org_id', orgId)
      .gte('date', sevenDaysAgoStr)
      .lt('date', todayStr)
      .order('date', ascending: true)
      .execute();

  if (response.status != 200 || response.data == null) {
    throw Exception('Failed to fetch data: HTTP ${response.status}');
  }

  return List<Map<String, dynamic>>.from(response.data);
});
