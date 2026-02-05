import 'package:flutter/material.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Us'),
        backgroundColor: const Color(0xFF8B5CF6),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'KAPiLa Learning વિશે',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'KAPiLa Learning એ એક Digital Learning Platform છે. અમે students ને mock tests, practice exams અને performance analysis tools પ્રદાન કરીએ છીએ. અમારી માધ્યમથી વિદ્યાર્થી સરળ અને structured રીતે પરીક્ષા માટે તૈયારી કરી શકે છે.',
              style: TextStyle(fontSize: 16, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
