import 'package:flutter/material.dart';

class NandigramPrivacyPolicyScreen extends StatelessWidget {
  const NandigramPrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'KAPILA Learning - Nandigram',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Last Updated: February 2026',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          _buildSection(
            '1. માહિતી જે અમે એકત્રિત કરીએ છીએ',
            'અમે નીચેની માહિતી એકત્રિત કરીએ છીએ:\n\n'
            '• Account માહિતી: નામ, email, phone number\n'
            '• Profile માહિતી: profile photo, bio, જન્મ તારીખ\n'
            '• Content: messages, posts, media files\n'
            '• Usage data: app activity, device information\n'
            '• Location data (optional): તમારી permission સાથે',
          ),

          _buildSection(
            '2. માહિતીનો ઉપયોગ',
            'અમે તમારી માહિતીનો ઉપયોગ આ માટે કરીએ છીએ:\n\n'
            '• તમને services પ્રદાન કરવા\n'
            '• App અનુભવ સુધારવા\n'
            '• સુરક્ષા અને fraud prevention\n'
            '• તમને relevant content બતાવવા\n'
            '• Technical support આપવા',
          ),

          _buildSection(
            '3. માહિતી sharing',
            'અમે તમારી માહિતી આ રીતે share કરીએ છીએ:\n\n'
            '• અન્ય users સાથે: તમે જે content public કરો છો\n'
            '• Service providers: hosting, analytics (Supabase, Firebase)\n'
            '• કાયદાકીય જરૂરિયાત: જો કાયદો માંગે\n\n'
            'અમે તમારી personal માહિતી third parties ને વેચતા નથી.',
          ),

          _buildSection(
            '4. Data સુરક્ષા',
            'અમે તમારી માહિતીની સુરક્ષા માટે:\n\n'
            '• Encryption વાપરીએ છીએ\n'
            '• Secure servers (Supabase)\n'
            '• Regular security audits\n'
            '• Access controls અને authentication',
          ),

          _buildSection(
            '5. તમારા અધિકારો',
            'તમને આ અધિકારો છે:\n\n'
            '• તમારી માહિતી જોવાનો\n'
            '• માહિતી સુધારવાનો\n'
            '• Account delete કરવાનો\n'
            '• Data portability\n'
            '• Marketing emails માંથી opt-out',
          ),

          _buildSection(
            '6. Cookies અને Tracking',
            'અમે cookies અને similar technologies વાપરીએ છીએ:\n\n'
            '• Session management\n'
            '• Preferences save કરવા\n'
            '• Analytics (Firebase, Google Analytics)\n'
            '• App performance tracking',
          ),

          _buildSection(
            '7. બાળકોની Privacy',
            'આ app 13 વર્ષથી નીચેના બાળકો માટે નથી. '
            'જો તમે 18 વર્ષથી નીચેના હો, તો parent/guardian ની permission લો.',
          ),

          _buildSection(
            '8. Policy Changes',
            'અમે આ policy સમયાંતરે update કરી શકીએ છીએ. '
            'Changes થાય ત્યારે અમે app માં notification મોકલીશું.',
          ),

          _buildSection(
            '9. અમારો સંપર્ક',
            'Privacy સંબંધિત પ્રશ્નો માટે:\n\n'
            'Email: privacy@kapilalearning.com\n'
            'App: Settings → Ask & Feedback\n'
            'Address: Ahmedabad, Gujarat, India',
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
                      Icon(Icons.security_outlined, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'તમારી Privacy મહત્વપૂર્ણ છે',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'અમે તમારી માહિતીની સુરક્ષા અને privacy ને ગંભીરતાથી લઈએ છીએ. '
                    'Settings → Privacy & Security માં તમે તમારી privacy settings control કરી શકો છો.',
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

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(height: 1.6),
          ),
        ],
      ),
    );
  }
}