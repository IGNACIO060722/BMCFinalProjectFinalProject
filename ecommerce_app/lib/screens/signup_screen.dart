import 'package:flutter/material.dart';
import 'package:ecommerce_app/screens/login_screen.dart'; // Changed to relative import
import 'package:firebase_auth/firebase_auth.dart'; // 1. Add Firebase Auth import
import 'package:cloud_firestore/cloud_firestore.dart'; // 1. ADD THIS IMPORT

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();


  // 2. Add loading state and auth instance
  bool _isLoading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // 2. ADD THIS


  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }


  // 3. The Sign Up Function
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }


    setState(() {
      _isLoading = true;
    });


    try {
      // 3. This is the same: create the user
      final UserCredential userCredential =
      await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );


      // 4. --- THIS IS THE NEW PART ---
      // After creating the user, save their info to Firestore
      if (userCredential.user != null) {
        // 5. Create a document in a 'users' collection
        //    We use the user's unique UID as the document ID
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'email': _emailController.text.trim(),
          'role': 'user', // 6. Set the default role to 'user'
          'createdAt': FieldValue.serverTimestamp(), // For our records
        });
      }
      // 7. The AuthWrapper will handle navigation automatically


      // 2. AuthWrapper will auto-navigate to HomeScreen.

    } on FirebaseAuthException catch (e) {
      // 3. Handle specific sign-up errors
      String message = 'An error occurred';
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists for that email.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An unexpected error occurred'),
          backgroundColor: Colors.blue,
        ),
      );


    } finally {
      if(mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('𝐒𝐢𝐠𝐧 𝐔𝐩'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),


                // Email Text Field
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),


                const SizedBox(height: 16),


                // Password Text Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),


                const SizedBox(height: 20),


                // Sign Up Button - UPDATED
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  // 1. Call our new _signUp function
                  onPressed: _isLoading ? null : _signUp,
                  // 2. Show a spinner OR text
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  )
                      : const Text('Sign Up'),
                ),

                const SizedBox(height: 10),

                // Login Button - FIXED NAVIGATION
                TextButton(
                  onPressed: _isLoading ? null : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  child: const Text("Already have an account? Login"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}