// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'screens/home_screen.dart';
import 'screens/nft_vault_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/offers_screen.dart';
import 'screens/login_page.dart';
import 'screens/profile_screen.dart';

import 'firebase_options.dart';

const String __app_id = String.fromEnvironment('APP_ID', defaultValue: 'default-app-id');
const String __firebase_config = String.fromEnvironment('FIREBASE_CONFIG', defaultValue: '{}');
const String __initial_auth_token = String.fromEnvironment('INITIAL_AUTH_token', defaultValue: '');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Firebase initialized successfully.");

    final FirebaseAuth auth = FirebaseAuth.instance;

    if (__initial_auth_token.isNotEmpty) {
      try {
        debugPrint("Attempting sign-in with custom token...");
        await auth.signInWithCustomToken(__initial_auth_token);
        debugPrint("Signed in with custom token.");
      } on FirebaseAuthException catch (e) {
        debugPrint("Failed to sign in with custom token: ${e.code} - ${e.message}. Attempting anonymous sign-in.");
        await auth.signInAnonymously();
        debugPrint("Signed in anonymously after custom token failure.");
      } catch (e) {
        debugPrint("An unexpected error during custom token sign-in: $e. Attempting anonymous sign-in.");
        await auth.signInAnonymously();
        debugPrint("Signed in anonymously after unexpected error.");
      }
    } else {
      debugPrint("No initial auth token provided. Signing in anonymously.");
      await auth.signInAnonymously();
      debugPrint("Signed in anonymously.");
    }

    if (auth.currentUser != null) {
      debugPrint("Current authenticated user UID: ${auth.currentUser!.uid}");
    } else {
      debugPrint("No user authenticated after initial attempts.");
    }

  } catch (e) {
    debugPrint("Error initializing Firebase or during initial authentication: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: const ValueKey('mainApp'),
      title: 'Screen Time Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: GoogleFonts.montserratTextTheme(
          Theme.of(context).textTheme,
        ).apply(
          bodyColor: Colors.black87,
          displayColor: Colors.black87,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: GoogleFonts.montserrat(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.blue.shade700,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.blue.shade200,
          selectedLabelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.montserrat(),
          type: BottomNavigationBarType.fixed,
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            debugPrint("Auth state: Waiting for connection...");
            return const Scaffold(
              key: ValueKey('loadingScreen'),
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            debugPrint("Auth state: Error - ${snapshot.error}");
            return Scaffold(
              key: const ValueKey('errorScreen'),
              body: Center(
                child: Text('Error: ${snapshot.error}', style: GoogleFonts.montserrat(color: Colors.red)),
              ),
            );
          }
          if (snapshot.hasData && snapshot.data != null) {
            debugPrint("Auth state: User logged in.");
            return const MainScreen();
          } else {
            debugPrint("Auth state: No user logged in. Showing LoginPage.");
            return const LoginPage();
          }
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    debugPrint("MainScreen initState called.");
    _pages = [
      const HomeScreen(key: PageStorageKey('homeScreen')),
      const NftVaultScreen(key: PageStorageKey('nftVaultScreen')),
      const WalletScreen(key: PageStorageKey('walletScreen')),
      const OffersScreen(key: PageStorageKey('offersScreen')),
      const ProfileScreen(key: PageStorageKey('profileScreen')),
    ];
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.jumpToPage(index);
    });
  }

  @override
  void dispose() {
    debugPrint("MainScreen dispose called.");
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("MainScreen build called.");
    final User? user = FirebaseAuth.instance.currentUser;
    final String userName = user?.uid.substring(0, 8) ?? "Guest";

    return Scaffold(
      key: const ValueKey('mainScreenScaffold'),
      appBar: AppBar(
        title: Text(
          '${_getGreeting()}, $userName',
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.person,
                color: Colors.blue.shade700,
                size: 25,
              ),
            ),
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.security_rounded),
            label: 'NFT Vault',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_offer_rounded),
            label: 'Offers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class NftVaultScreen extends StatelessWidget {
  const NftVaultScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.security_rounded, size: 80, color: Colors.blue.shade300),
          const SizedBox(height: 20),
          Text('NFT Vault Coming Soon!', style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
          const SizedBox(height: 10),
          Text('Manage your digital collectibles here.', style: GoogleFonts.montserrat(fontSize: 16, color: Colors.grey.shade600), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_rounded, size: 80, color: Colors.blue.shade300),
          const SizedBox(height: 20),
          Text('Your Digital Wallet', style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
          const SizedBox(height: 10),
          Text('Securely store and manage your assets.', style: GoogleFonts.montserrat(fontSize: 16, color: Colors.grey.shade600), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class OffersScreen extends StatelessWidget {
  const OffersScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_offer_rounded, size: 80, color: Colors.blue.shade300),
          const SizedBox(height: 20),
          Text('Exclusive Offers', style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
          const SizedBox(height: 10),
          Text('Discover great deals and rewards.', style: GoogleFonts.montserrat(fontSize: 16, color: Colors.grey.shade600), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings_rounded, size: 80, color: Colors.blue.shade300),
          const SizedBox(height: 20),
          Text('Settings (Placeholder)', style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
          const SizedBox(height: 10),
          Text('This tab could be used for general app settings.', style: GoogleFonts.montserrat(fontSize: 16, color: Colors.grey.shade600), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
