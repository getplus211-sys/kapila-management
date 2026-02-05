import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: const Color(0xFF8B5CF6),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Privacy Policy',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'KAPiLa Learning તમારા personal information ની privacy ને મહત્વ આપે છે અને તેને સુરક્ષિત રાખે છે. અમારું objective છે કે students સરળ અને safe environment માં study કરે.',
              style: TextStyle(fontSize: 16, height: 1.6),
            ),
            SizedBox(height: 16),
            Text('We collect:'),
            Text('- Name, email, mobile number\n- Login credentials\n- Payment details\n- Mock test attempts and scores', style: TextStyle(fontSize: 16, height: 1.6)),
            SizedBox(height: 12),
            Text('Use of information:'),
            Text('- Provide access to mock tests\n- Improve analytics\n- Send notifications\n- Customer support', style: TextStyle(fontSize: 16, height: 1.6)),
          ],
        ),
      ),
    );
  }
}
