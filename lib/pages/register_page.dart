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

    try {
      // Sign up the user in Supabase
      final AuthResponse response = await _supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = response.user;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signup failed. Please try again.')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

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
        print('Error creating profile:');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error creating profile.')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Generate a 6-digit join code
      final String joinCode =
          (100000 + (DateTime.now().millisecondsSinceEpoch % 900000))
              .toString();

      // Create an organization for the new user with the join code
      final organizationResponse =
          await _supabase.from('organizations').insert({
        'name': '${_fullNameController.text.trim()}\'s Organization',
        'owner_id': user.id,
        'join_code': joinCode,
      }).execute();

      if (organizationResponse.status != 201) {
        print('Error creating organization:');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating organization:')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Add user to their new organization as an owner
      final membershipResponse =
          await _supabase.from('user_organization_membership').insert({
        'user_id': user.id,
        'organization_id': organizationResponse.data[0]
            ['id'], // Use the id from the organization insert
        'role': 'owner',
      }).execute();

      if (membershipResponse.status != 201) {
        print('Error adding user to organization: ');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error adding user to organization.')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration successful!')),
      );
      Navigator.push(
          context, MaterialPageRoute(builder: (context) => const AuthGate()));
    } catch (e) {
      print('Exception during registration: $e');
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
