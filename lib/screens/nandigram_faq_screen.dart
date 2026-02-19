import 'package:flutter/material.dart';

class NandigramFAQScreen extends StatelessWidget {
  const NandigramFAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nandigram FAQ'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFAQItem(
            'નંદીગ્રામ શું છે?',
            'નંદીગ્રામ એ KAPILA Learning નો સોશિયલ મીડિયા પ્લેટફોર્મ છે જ્યાં તમે મિત્રો સાથે chat કરી શકો, posts share કરી શકો અને ભણતર સંબંધિત માહિતી મેળવી શકો.',
          ),
          _buildFAQItem(
            'કેવી રીતે account બનાવું?',
            '1. KAPILA Learning app ડાઉનલોડ કરો\n2. Sign Up પર click કરો\n3. તમારી માહિતી ભરો\n4. Mobile number verify કરો\n5. Profile setup કરો',
          ),
          _buildFAQItem(
            'Password કેવી રીતે reset કરું?',
            'Login screen પર "Forgot Password" click કરો. તમારા registered email પર reset link મોકલવામાં આવશે.',
          ),
          _buildFAQItem(
            'Group અને Channel માં શું તફાવત છે?',
            'Group: બધા members message મોકલી શકે છે\nChannel: ફક્ત admins જ message મોકલી શકે છે, members માત્ર જોઈ શકે છે',
          ),
          _buildFAQItem(
            'કેવી રીતે post share કરું?',
            'Posts screen પર જઈને + button click કરો. Content લખો, media add કરો અને Post button દબાવો.',
          ),
          _buildFAQItem(
            'Quiz કેવી રીતે આપું?',
            'Home screen પર તમારા subject select કરો → Chapter select કરો → Quiz પર click કરો અને શરૂ કરો.',
          ),
          _buildFAQItem(
            'Privacy settings ક્યાં છે?',
            'Settings → Privacy & Security માં જઈને તમે block, last seen, profile photo વગેરે settings બદલી શકો છો.',
          ),
          _buildFAQItem(
            'Notifications કેવી રીતે બંધ કરું?',
            'Settings → Notifications & Sounds માં જઈને notifications toggle કરી શકો છો.',
          ),
          _buildFAQItem(
            'Account કેવી રીતે delete કરું?',
            'Settings → Privacy & Security → Delete Account પર જાઓ. આ permanent છે અને undo થઈ શકે નહીં.',
          ),
          _buildFAQItem(
            'Support કેવી રીતે contact કરું?',
            'Settings → Ask & Feedback માં જઈને તમારી સમસ્યા અથવા feedback મોકલો. અમારી team 24-48 કલાકમાં જવાબ આપશે.',
          ),
          const SizedBox(height: 20),
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.help_outline, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'વધુ મદદ જોઈએ?',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'તમારો પ્રશ્ન અહીં નથી? Settings → Ask & Feedback માં જઈને અમને સંપર્ક કરો.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              answer,
              style: const TextStyle(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}