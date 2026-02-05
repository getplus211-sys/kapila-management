import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/performance_screen.dart';
import 'screens/posts_screen.dart';
import 'screens/chat_list_screen.dart'; // 👈 બદલાવ: ChatScreen ને બદલે ChatListScreen
import 'screens/profile_screen.dart';
import 'screens/login_screen.dart';
import 'screens/global_search_screen.dart';
import 'screens/create_post_screen.dart';
// નવા chat સ્ક્રીન્સ
import 'screens/chat_window_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/saved_messages_screen.dart';
import 'screens/new_group_screen.dart';
import 'screens/new_channel_screen.dart';
import 'screens/create_story_screen.dart';
import 'widgets/bottom_nav_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://bhmycvrbucmbbrpzeane.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJobXljdnJidWNtYmJycHplYW5lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ2OTQwOTYsImV4cCI6MjA4MDI3MDA5Nn0.qQ3bw9cADG0P8hbGwx76Oeg54l-9FbRWxc92nZdSPL4',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KAPILA Learning',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        // ગુજરાતી ટેક્સ્ટ માટે યોગ્ય ફોન્ટ
        fontFamily: 'Roboto',
      ),
      home: const AuthWrapper(),
      routes: {
        '/global_search': (context) => const GlobalSearchScreen(),
        '/create_post': (context) => const CreatePostScreen(),
        // નવા chat routes
        '/contacts': (context) => const ContactsScreen(),
        '/saved_messages': (context) => const SavedMessagesScreen(),
        '/new_group': (context) => const NewGroupScreen(),
        '/new_channel': (context) => const NewChannelScreen(),
        '/create_story': (context) => const CreateStoryScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.session != null) {
          return const MainScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const PerformanceScreen(),
    const PostsScreen(),
    const ChatListScreen(), // 👈 બદલાવ: નવી ChatListScreen
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}