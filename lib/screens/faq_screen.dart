import 'package:flutter/material.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQ'),
        backgroundColor: const Color(0xFF8B5CF6),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ExpansionTile(
            title: const Text('Credits શું છે?', style: TextStyle(fontWeight: FontWeight.bold)),
            children: const [Padding(padding: EdgeInsets.all(8.0), child: Text('Credits એ virtual currency છે mock tests માટે.'))],
          ),
          ExpansionTile(
            title: const Text('હું credits કેવી રીતે મેળવી શકું?', style: TextStyle(fontWeight: FontWeight.bold)),
            children: const [Padding(padding: EdgeInsets.all(8.0), child: Text('Students regular tests આપતા credits મેળવે છે.'))],
          ),
          ExpansionTile(
            title: const Text('કેટલા પ્રકારની tests ઉપલબ્ધ છે?', style: TextStyle(fontWeight: FontWeight.bold)),
            children: const [Padding(padding: EdgeInsets.all(8.0), child: Text('1. Regular tests (Free)\n2. Premium mock tests (credits જરૂરી)'))],
          ),
          ExpansionTile(
            title: const Text('મારી rank કેવી રીતે નક્કી થાય?', style: TextStyle(fontWeight: FontWeight.bold)),
            children: const [Padding(padding: EdgeInsets.all(8.0), child: Text('Performance અને other students સાથે comparison પર આધારિત.'))],
          ),
          ExpansionTile(
            title: const Text('હું password ભૂલી ગયો તો શું કરવું?', style: TextStyle(fontWeight: FontWeight.bold)),
            children: const [Padding(padding: EdgeInsets.all(8.0), child: Text('Login page પર Forgot Password link થી password reset કરો.'))],
          ),
        ],
      ),
    );
  }
}
