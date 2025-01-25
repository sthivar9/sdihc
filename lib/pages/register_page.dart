import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sdihc/auth/authGate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _registerUser() async {
    setState(() {
      _isLoading = true;
    });

    // Input validation
    if (_emailController.text.trim().isEmpty ||
        !_emailController.text.trim().contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    if (_passwordController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Password must be at least 6 characters long.')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    if (_fullNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your full name.')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Sign up the user
      final AuthResponse response = await _supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user == null) {
        throw Exception('Signup failed. User is null.');
      }

      final user = response.user!;

      // Generate an 8-digit class ID
      final String classId =
          (10000000 + (DateTime.now().millisecondsSinceEpoch % 90000000))
              .toString();

      // Insert a new profile record in the 'profiles' table
      final profileResponse = await _supabase.from('profiles').insert({
        'user_id': user.id,
        'class_id': classId,
        'full_name': _fullNameController.text.trim(),
      }).execute();

      if (profileResponse.status != 201) {
        throw Exception(
            'Failed to create profile. Status: ${profileResponse.status}');
      }

      // Generate a 6-digit join code (as an integer)
      final int joinCode =
          100000 + (DateTime.now().millisecondsSinceEpoch % 900000);

      // Create an organization for the new user with the join code
      print('Inserting organization with data:');
      print({
        'name': '${_fullNameController.text.trim()}\'s Organization',
        'owner_id': user.id,
        'join_code': joinCode,
      });

      final organizationResponse = await _supabase
          .from('organizations')
          .insert({
            'name': '${_fullNameController.text.trim()}\'s Organization',
            'owner_id': user.id,
            'join_code': joinCode,
          })
          .select() // Add this line to return the inserted row
          .execute();

      print('Organization Response Status: ${organizationResponse.status}');
      print('Organization Response Data: ${organizationResponse.data}');

      if (organizationResponse.status != 201) {
        throw Exception(
            'Failed to create organization. Status: ${organizationResponse.status}');
      }

      if (organizationResponse.data == null ||
          organizationResponse.data.isEmpty) {
        throw Exception(
            'Failed to create organization. Response data is null or empty.');
      }

      final organizationId = organizationResponse.data[0]['id'];
      if (organizationId == null) {
        throw Exception('Organization ID is null.');
      }

      // Add user to their new organization as an owner
      final membershipResponse =
          await _supabase.from('user_organization_membership').insert({
        'user_id': user.id,
        'organization_id': organizationId,
        'role': 'owner',
      }).execute();

      if (membershipResponse.status != 201) {
        throw Exception(
            'Failed to add user to organization. Status: ${membershipResponse.status}');
      }

      // Show success message and navigate to the next screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration successful!')),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AuthGate()),
      );
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auth Error: ${e.message}')),
      );
    } on PostgrestException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Database Error: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
              ),
            ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _registerUser,
                    child: const Text('Register'),
                  ),
          ],
        ),
      ),
    );
  }
}
