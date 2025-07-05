// lib/screens/offers_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
          Text(
            'Exclusive Offers',
            style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
          ),
          const SizedBox(height: 10),
          Text(
            'Discover great deals and rewards.',
            style: GoogleFonts.montserrat(fontSize: 16, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
