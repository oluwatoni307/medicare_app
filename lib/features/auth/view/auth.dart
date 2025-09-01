import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_viewmodel.dart';

enum AuthMode { signIn, signUp, forgotPassword }

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AuthMode _authMode = AuthMode.signIn;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  // Track if reset email was sent successfully
  bool _resetEmailSent = false;

  // Helper getters for cleaner code
  bool get _isSignUp => _authMode == AuthMode.signUp;
  bool get _isSignIn => _authMode == AuthMode.signIn;
  bool get _isForgotPassword => _authMode == AuthMode.forgotPassword;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // disables going back
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Consumer<AuthViewModel>(
              builder: (context, authViewModel, child) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 60),
                      
                      // Title
                      Text(
                        _getTitle(),
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      
                      if (_isForgotPassword && !_resetEmailSent)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            "Enter your email address and we'll send you a reset link",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      
                      SizedBox(height: 40),

                      // Show success message prominently if reset email sent
                      if (_resetEmailSent && _isForgotPassword)
                        _buildEmailSentSuccess(),

                      // Form fields (only show if email hasn't been sent yet)
                      if (!_resetEmailSent) ..._buildFormFields(),

                      SizedBox(height: 20),

                      // Error message
                      if (authViewModel.errorMessage.isNotEmpty)
                        _buildErrorMessage(authViewModel.errorMessage),

                      // Success message (for non-forgot password actions)
                      if (authViewModel.successMessage.isNotEmpty && !_isForgotPassword)
                        _buildSuccessMessage(authViewModel.successMessage),

                      SizedBox(height: 20),

                      // Main action button (only show if email hasn't been sent)
                      if (!_resetEmailSent)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: authViewModel.isLoading ? null : _handleMainAction,
                            child: authViewModel.isLoading
                                ? CircularProgressIndicator(color: Colors.white)
                                : Text(_getButtonText()),
                          ),
                        ),

                      SizedBox(height: 16),

                      // Secondary actions
                      ..._buildSecondaryActions(authViewModel),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailSentSuccess() {
    return Container(
      padding: EdgeInsets.all(20),
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.email_outlined,
            size: 48,
            color: Colors.green.shade600,
          ),
          SizedBox(height: 12),
          Text(
            "Check Your Email",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "We've sent a password reset link to ${_emailController.text}",
            style: TextStyle(
              fontSize: 14,
              color: Colors.green.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            "Click the link in the email to reset your password",
            style: TextStyle(
              fontSize: 12,
              color: Colors.green.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(String message) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage(String message) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.green.shade700),
            ),
          ),
        ],
      ),
    );
  }

  String _getTitle() {
    switch (_authMode) {
      case AuthMode.signIn:
        return "Welcome Back";
      case AuthMode.signUp:
        return "Create Account";
      case AuthMode.forgotPassword:
        return _resetEmailSent ? "Email Sent!" : "Forgot Password";
    }
  }

  String _getButtonText() {
    switch (_authMode) {
      case AuthMode.signIn:
        return "Sign In";
      case AuthMode.signUp:
        return "Sign Up";
      case AuthMode.forgotPassword:
        return "Send Reset Email";
    }
  }

  List<Widget> _buildFormFields() {
    List<Widget> fields = [];

    // Name field (only for sign up)
    if (_isSignUp) {
      fields.addAll([
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: "Name",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        SizedBox(height: 16),
      ]);
    }

    // Email field (always present)
    fields.addAll([
      TextField(
        controller: _emailController,
        decoration: InputDecoration(
          labelText: "Email",
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.email_outlined),
        ),
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
      ),
      SizedBox(height: 16),
    ]);

    // Password field (not for forgot password)
    if (!_isForgotPassword) {
      fields.addAll([
        TextField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: "Password",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock_outline),
          ),
          obscureText: true,
        ),
        SizedBox(height: 16),
      ]);
    }

    return fields;
  }

  List<Widget> _buildSecondaryActions(AuthViewModel authViewModel) {
    List<Widget> actions = [];

    if (_isSignIn) {
      // Forgot password link
      actions.add(
        TextButton(
          onPressed: () => _switchMode(AuthMode.forgotPassword),
          child: Text("Forgot Password?"),
        ),
      );
      
      // Switch to sign up
      actions.add(
        TextButton(
          onPressed: () => _switchMode(AuthMode.signUp),
          child: Text("Need an account? Sign Up"),
        ),
      );
    } else if (_isSignUp) {
      // Switch to sign in
      actions.add(
        TextButton(
          onPressed: () => _switchMode(AuthMode.signIn),
          child: Text("Already have an account? Sign In"),
        ),
      );
    } else if (_isForgotPassword) {
      if (_resetEmailSent) {
        // Resend email option
        actions.add(
          TextButton(
            onPressed: authViewModel.isLoading ? null : () async {
              await _handleSendResetEmail();
            },
            child: authViewModel.isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text("Resend Email"),
          ),
        );
        
        SizedBox(height: 8);
        
        // Back to sign in
        actions.add(
          ElevatedButton.icon(
            onPressed: () => _switchMode(AuthMode.signIn),
            icon: Icon(Icons.arrow_back),
            label: Text("Back to Sign In"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              foregroundColor: Colors.grey.shade700,
            ),
          ),
        );
      } else {
        // Back to sign in (before email sent)
        actions.add(
          TextButton(
            onPressed: () => _switchMode(AuthMode.signIn),
            child: Text("Back to Sign In"),
          ),
        );
      }
    }

    return actions;
  }

  void _switchMode(AuthMode newMode) {
    setState(() {
      _authMode = newMode;
      _resetEmailSent = false; // Reset email sent state
    });
    // Clear messages when switching modes
    Provider.of<AuthViewModel>(context, listen: false).clearMessages();
  }

  Future<void> _handleMainAction() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

    switch (_authMode) {
      case AuthMode.signIn:
        await authViewModel.signIn(_emailController.text, _passwordController.text);
        // Navigate to main app if user is signed in
        if (authViewModel.user != null) {
          Navigator.pushReplacementNamed(context, '/');
        }
        break;
        
      case AuthMode.signUp:
        await authViewModel.signUp(
          _emailController.text,
          _passwordController.text,
          name: _nameController.text.isEmpty ? 'User' : _nameController.text,
        );
        // Navigate to main app if user is signed in
        if (authViewModel.user != null) {
          Navigator.pushReplacementNamed(context, '/');
        }
        break;
        
      case AuthMode.forgotPassword:
        await _handleSendResetEmail();
        break;
    }
  }

  Future<void> _handleSendResetEmail() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    final success = await authViewModel.sendPasswordResetEmail(_emailController.text);
    
    if (success) {
      setState(() {
        _resetEmailSent = true;
      });
    }
  }
}

// Test widget to preview the AuthScreen
class AuthScreenPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auth Screen Preview',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: AuthScreen(),
    );
  }
}

// Usage: 
// To preview: AuthScreenPreview()
// To use in app: AuthScreen()