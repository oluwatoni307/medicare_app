import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth_viewmodel.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignUp = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return PopScope (
          canPop: false, // disables going back

      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Consumer<AuthViewModel>(
              builder: (context, authViewModel, child) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isSignUp ? "Create Account" : "Welcome Back",
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 40),
                    
                    if (_isSignUp) ...[
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(labelText: "Name"),
                      ),
                      SizedBox(height: 16),
                    ],
                    
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(labelText: "Email"),
                    ),
                    SizedBox(height: 16),
                    
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(labelText: "Password"),
                      obscureText: true,
                    ),
                    SizedBox(height: 20),
                    
                    if (authViewModel.errorMessage.isNotEmpty)
                      Text(authViewModel.errorMessage, style: TextStyle(color: Colors.red)),
                    
                    SizedBox(height: 20),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: authViewModel.isLoading ? null : _authenticate,
                        child: authViewModel.isLoading 
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(_isSignUp ? "Sign Up" : "Sign In"),
                      ),
                    ),
                    
                    TextButton(
                      onPressed: () => setState(() => _isSignUp = !_isSignUp),
                      child: Text(_isSignUp ? "Already have an account? Sign In" : "Need an account? Sign Up"),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _authenticate() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    if (_isSignUp) {
      await authViewModel.signUp(_emailController.text, _passwordController.text);
    } else {
      await authViewModel.signIn(_emailController.text, _passwordController.text);
    }
    
    if (authViewModel.user != null) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }
}