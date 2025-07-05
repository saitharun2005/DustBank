// lib/screens/wallet_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
          Text(
            'Your Digital Wallet',
            style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
          ),
          const SizedBox(height: 10),
          Text(
            'Securely store and manage your assets.',
            style: GoogleFonts.montserrat(fontSize: 16, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
