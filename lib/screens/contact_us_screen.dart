import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  Future<void> _launchPhone() async {
    final uri = Uri.parse('tel:+916353511804');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsapp() async {
    final uri = Uri.parse('https://wa.me/916353511804?text=Hello%20KAPiLa%20Learning');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchEmail() async {
    final uri = Uri.parse('mailto:devjoshi.jd24@gmail.com');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Us'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              color: const Color(0xFFEDE9FE),
              margin: const EdgeInsets.only(bottom: 24),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: const [
                    Icon(Icons.chat_bubble_outline, size: 60, color: Color(0xFF8B5CF6)),
                    SizedBox(height: 16),
                    Text(
                      'અમારી સાથે સંપર્ક કરો',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'કોઈપણ પ્રશ્ન માટે અમને સંપર્ક કરો. અમે 24 કલાકમાં જવાબ આપીશું.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.phone, color: Color(0xFF6366F1)),
                ),
                title: const Text(
                  'Phone Call',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('+91 6353511804'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _launchPhone,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '💬',
                    style: TextStyle(fontSize: 24),
                  ),
                ),
                title: const Text(
                  'WhatsApp',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('+91 6353511804'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _launchWhatsapp,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.email, color: Colors.blue),
                ),
                title: const Text(
                  'Email',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('devjoshi.jd24@gmail.com'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _launchEmail,
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Office Address',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'KAPILA Learning Institute\nAhmedabad, Gujarat, India',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}