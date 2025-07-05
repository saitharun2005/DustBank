// lib/screens/nft_vault_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
          Text(
            'NFT Vault Coming Soon!',
            style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
          ),
          const SizedBox(height: 10),
          Text(
            'Manage your digital collectibles here.',
            style: GoogleFonts.montserrat(fontSize: 16, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
