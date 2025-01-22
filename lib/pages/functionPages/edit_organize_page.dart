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

  @override
  void initState() {
    super.initState();
    _fetchOrganizations();
  }

  Future<void> _fetchOrganizations() async {
    try {
      final response = await _supabase
          .from('organizations')
          .select('name, join_code')
          .execute();

      if (response.status == 200 && response.data != null) {
        setState(() {
          _organizations = List<Map<String, dynamic>>.from(response.data);
        });
      } else {
        print(
            'Error fetching organizations: Status ${response.status}, Message: ');
      }
    } catch (e) {
      print('Exception fetching organizations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Organization'),
      ),
      body: Column(
        children: [
          // Row of Icon Buttons
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.person_add),
                  tooltip: 'Add Member',
                  onPressed: () {
                    // Navigate to add member page or show dialog
                    print('Add Member');
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.group_add),
                  tooltip: 'Join Organization',
                  onPressed: () {
                    // Navigate to join organization page or show dialog
                    print('Join Organization');
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.add_business),
                  tooltip: 'Add Organization',
                  onPressed: () {
                    // Navigate to add organization page or show dialog
                    print('Add Organization');
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _organizations.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _organizations.length,
                    itemBuilder: (context, index) {
                      final org = _organizations[index];
                      return ListTile(
                        title: Text(org['name']),
                        subtitle:
                            Text('Join Code: ${org['join_code'] ?? 'Not Set'}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
