// lib/screens/login_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math'; // For generating random alphanumeric ID

// Import MainScreen to navigate to it
import '../main.dart'; // Assuming main.dart is in the parent directory

// Global app ID (from main.dart)
const String __app_id = String.fromEnvironment('APP_ID', defaultValue: 'default-app-id');

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Function to show a SnackBar message
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.montserrat()),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Function to generate a 4-digit alphanumeric user ID
  String _generateRandomAlphanumeric(int length) {
    const String chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    Random random = Random();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  Future<void> _registerNewUserFlow() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final String generatedUserId = _generateRandomAlphanumeric(4);

    String? password = await _promptForPassword(context, generatedUserId);

    if (!mounted) return;
    if (password == null || password.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar("Password cannot be empty. Registration cancelled.", isError: true);
      return;
    }

    final String emailForAuth = "$generatedUserId@screentimeapp.com";

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: emailForAuth,
        password: password,
      );

      if (!mounted) return;
      if (userCredential.user != null) {
        final userId = userCredential.user!.uid;
        final profileRef = _firestore.collection('artifacts').doc(__app_id).collection('users').doc(userId).collection('profile').doc('details');

        debugPrint("Attempting to save profile for UID: $userId under path: ${profileRef.path}");
        try {
          await profileRef.set({
            'displayUserId': generatedUserId,
            'email': emailForAuth,
            'createdAt': FieldValue.serverTimestamp(),
          });
          debugPrint("User profile saved successfully to Firestore.");
          _showSnackBar("Account created successfully! Your User ID is: $generatedUserId");

          // IMPORTANT: Navigate to MainScreen after successful registration and profile save
          if (mounted) {
            // Add a small delay to ensure Firebase Auth state is fully propagated
            await Future.delayed(const Duration(milliseconds: 500));
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainScreen()),
            );
          }
        } on FirebaseException catch (firestoreError) {
          debugPrint("Firestore Error saving user profile: ${firestoreError.code} - ${firestoreError.message}");
          _showSnackBar("Failed to save profile data: ${firestoreError.message}", isError: true);
        } catch (e) {
          debugPrint("Unexpected Error saving user profile: $e");
          _showSnackBar("An unexpected error occurred while saving profile: $e", isError: true);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message;
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'A user with this ID already exists. Please try again.';
      } else {
        message = 'Registration failed: ${e.message}';
      }
      _showSnackBar(message, isError: true);
      debugPrint("Firebase Auth Error during registration: $e");
    } catch (e) {
      if (!mounted) return;
      _showSnackBar("An unexpected error occurred: $e", isError: true);
      debugPrint("Error during registration: $e");
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String?> _promptForPassword(BuildContext context, String generatedUserId) async {
    TextEditingController tempPasswordController = TextEditingController();
    String? password;

    await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Set Your Password", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text("Your new User ID is:", style: GoogleFonts.montserrat()),
                SelectableText(
                  generatedUserId,
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.blue.shade700),
                ),
                const SizedBox(height: 15),
                Text("Please set a password for your account:", style: GoogleFonts.montserrat()),
                TextField(
                  controller: tempPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Minimum 6 characters',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  style: GoogleFonts.montserrat(),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text("Cancel", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Confirm", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
              onPressed: () {
                if (tempPasswordController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Password must be at least 6 characters long.", style: GoogleFonts.montserrat()),
                      backgroundColor: Colors.red.shade700,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } else {
                  password = tempPasswordController.text;
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
    tempPasswordController.dispose();
    return password;
  }

  Future<void> _loginUser() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final String userId = _userIdController.text.trim();
    final String password = _passwordController.text.trim();
    final String emailForAuth = "$userId@screentimeapp.com";

    if (userId.isEmpty || password.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showSnackBar("Please enter your User ID and Password.", isError: true);
      return;
    }

    try {
      await _auth.signInWithEmailAndPassword(email: emailForAuth, password: password);
      if (!mounted) return;
      _showSnackBar("Login successful!");

      // IMPORTANT: Navigate to MainScreen after successful login
      if (mounted) {
        // Add a small delay to ensure Firebase Auth state is fully propagated
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message;
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        message = 'Invalid User ID or password.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid User ID format. Please check your ID.';
      } else {
        message = 'Login failed: ${e.message}';
      }
      _showSnackBar(message, isError: true);
      debugPrint("Firebase Auth Error during login: $e");
    } catch (e) {
      if (!mounted) return;
      _showSnackBar("An unexpected error occurred: $e", isError: true);
      debugPrint("Error during login: $e");
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Screen Time Tracker',
          style: GoogleFonts.montserrat(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome to Screen Time Tracker!',
                style: GoogleFonts.montserrat(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _userIdController,
                decoration: InputDecoration(
                  labelText: 'Your User ID',
                  hintText: 'Enter your 4-digit ID',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person_rounded),
                ),
                style: GoogleFonts.montserrat(),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock_rounded),
                ),
                style: GoogleFonts.montserrat(),
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loginUser,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Login',
                              style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: _registerNewUserFlow,
                          child: Text(
                            'New User? Register New Account',
                            style: GoogleFonts.montserrat(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
