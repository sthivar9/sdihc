import 'package:flutter/material.dart';
import 'package:sdihc/pages/Tabs/newAddSalesTab.dart';
import 'package:sdihc/pages/functionPages/inventory_screen.dart';
import 'package:sdihc/pages/functionPages/submit_bill_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddSalesTab extends StatefulWidget {
  const AddSalesTab({super.key});

  @override
  _AddSalesTabState createState() => _AddSalesTabState();
}

class _AddSalesTabState extends State<AddSalesTab> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _amountController = TextEditingController();
  DateTime? _selectedDate;

  bool _isLoading = false;

  final TextEditingController _manualClassIdController =
      TextEditingController();

  // Function to handle date picker
  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _addSalesData() async {
    // Check user authentication
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _showSnackBar('User  not authenticated');
      return;
    }

    // Validate input fields
    if (_amountController.text.isEmpty || _selectedDate == null) {
      _showSnackBar('Please fill all fields');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final amount = double.tryParse(_amountController.text);
    if (amount == null) {
      _showSnackBar('Invalid amount');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Fetch class_id from profiles table
      final profileResponse = await _supabase
          .from('profiles') // Updated table name
          .select('class_id')
          .eq('user_id', user.id)
          .single()
          .execute();

      if (profileResponse.status != 200 || profileResponse.data == null) {
        _showSnackBar('Error fetching profile data');
        return;
      }

      // Extract class_id from the profile response
      String classId = profileResponse.data['class_id'];

      // Use the manually provided class_id if entered by the user
      if (_manualClassIdController.text.isNotEmpty) {
        classId = _manualClassIdController.text;
      }

      // Format the date to 'YYYY-MM-DD'
      final String formattedDate =
          _selectedDate!.toIso8601String().split('T')[0];

      // Check for existing sales data
      final existingRowResponse = await _supabase
          .from('sales')
          .select()
          .eq('date', formattedDate)
          .eq('class_id', classId)
          .maybeSingle()
          .execute();

      if (existingRowResponse.status == 200 &&
          existingRowResponse.data != null) {
        // Update existing sales data
        final updateResponse = await _supabase
            .from('sales')
            .update({'amount': amount})
            .eq('date', formattedDate)
            .eq('class_id', classId)
            .execute();

        if (updateResponse.status == 204) {
          _showSnackBar('Sales data updated successfully');
        } else {
          _showSnackBar('Error updating data: ${updateResponse.status}');
        }
      } else if (existingRowResponse.status == 200) {
        // Insert new sales data
        final insertResponse = await _supabase.from('sales').insert({
          'date': formattedDate,
          'amount': amount,
          'class_id': classId,
        }).execute();

        if (insertResponse.status == 201) {
          _showSnackBar('Sales data added successfully');
        } else {
          _showSnackBar('Error inserting data: ${insertResponse.status}');
        }
      } else {
        _showSnackBar(
            'Error checking existing data: ${existingRowResponse.status}');
      }
    } catch (e) {
      _showSnackBar('Error adding sales data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add Sales Data',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Sales Amount',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedDate == null
                                ? 'No date selected'
                                : 'Date: ${_selectedDate!.toLocal()}'
                                    .split(' ')[0],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _pickDate,
                          child: const Text('Pick Date'),
                        ),
                      ],
                    ),
                    TextField(
                      controller: _manualClassIdController,
                      decoration: const InputDecoration(
                        labelText: 'Class ID (optional)',
                        hintText: 'Enter Class ID to share data',
                      ),
                    ),
                    const SizedBox(height: 20),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _addSalesData,
                            child: const Text('Add Sales'),
                          ),
                    SizedBox(
                      height: 90,
                    ),
                    Row(
                      children: [
                        ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const SubmitBillScreen()),
                              );
                            },
                            child: Text("bill Submit")),
                        ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const BillsScreen()),
                              );
                            },
                            child: Text("bills")),
                        ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const Addpage()),
                              );
                            },
                            child: Text("Add Page")),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
