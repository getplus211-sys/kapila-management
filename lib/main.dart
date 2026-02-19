import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'services/local_storage_service.dart';
import 'services/chat_service.dart';
import 'utils/connectivity_handler.dart';
import 'screens/home_screen.dart';
import 'screens/performance_screen.dart';
import 'screens/posts_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/login_screen.dart';
import 'screens/global_search_screen.dart';
import 'screens/create_post_screen.dart';
import 'screens/chat_window_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/saved_messages_screen.dart';
import 'screens/new_group_screen.dart';
import 'screens/new_channel_screen.dart';
import 'screens/create_story_screen.dart';
import 'screens/all_stories_screen.dart';
import 'screens/view_stories_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/post_detail_screen.dart';
import 'screens/quiz_engine_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/theme_provider.dart';
import 'models/user_model.dart';
import 'widgets/bottom_nav_bar.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Color(0xFF0B0E1A),
    systemNavigationBarIconBrightness: Brightness.light,
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // ✅ PARALLEL initialization - FAST!
  await Future.wait([
    LocalStorageService().init(),
    ConnectivityHandler().initialize(),
    Supabase.initialize(
      url: 'https://bhmycvrbucmbbrpzeane.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJobXljdnJidWNtYmJycHplYW5lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ2OTQwOTYsImV4cCI6MjA4MDI3MDA5Nn0.qQ3bw9cADG0P8hbGwx76Oeg54l-9FbRWxc92nZdSPL4',
    ),
  ]);

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _initSupabaseAuthListener();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('🔗 Cold start deep link: $initialUri');
        await Future.delayed(const Duration(milliseconds: 500));
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Cold start deep link error: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        debugPrint('🔗 Foreground deep link: $uri');
        _handleDeepLink(uri);
      },
      onError: (err) => debugPrint('Deep link stream error: $err'),
    );
  }

  void _initSupabaseAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      debugPrint('🔐 Auth event: $event');

      if (event == AuthChangeEvent.passwordRecovery) {
        debugPrint('🔑 Password recovery session detected');
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
          (route) => false,
        );
      }
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('🔗 Handling URI: $uri');
    debugPrint('   Host: ${uri.host}');
    debugPrint('   Path: ${uri.path}');

    final path = uri.path;
    final host = uri.host;
    final Map<String, String> params = _parseParams(uri);
    final String? type = params['type'];

    if (type == 'recovery') {
      debugPrint('✅ Password recovery detected');
      return;
    }

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;

      // Post
      if (host == 'post' || path.startsWith('/post/')) {
        final postId = _extractId(path, host, 'post');
        if (postId != null && postId.isNotEmpty) {
          debugPrint('📱 Opening post: $postId');
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => PostDetailScreen(postId: postId),
            ),
          );
        }
        return;
      }

      // Quiz
      if (host == 'quiz' || path.startsWith('/quiz/')) {
        final quizId = _extractId(path, host, 'quiz');
        if (quizId != null && quizId.isNotEmpty) {
          debugPrint('🎯 Opening quiz: $quizId');
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => QuizEngineScreen(quizId: quizId),
            ),
          );
        }
        return;
      }

      // Profile
      if (host == 'profile' || path.startsWith('/profile/')) {
        final userId = _extractId(path, host, 'profile');
        if (userId != null && userId.isNotEmpty) {
          debugPrint('👤 Opening profile: $userId');
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(userId: userId),
            ),
          );
        }
        return;
      }

      // Group
      if (host == 'group' || path.startsWith('/group/')) {
        final groupId = _extractId(path, host, 'group');
        if (groupId != null && groupId.isNotEmpty) {
          debugPrint('👥 Opening group: $groupId');
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => ChatWindowScreen(
                chatId: groupId,
                otherUserId: '',
              ),
            ),
          );
        }
        return;
      }

      // Channel
      if (host == 'channel' || path.startsWith('/channel/')) {
        final channelId = _extractId(path, host, 'channel');
        if (channelId != null && channelId.isNotEmpty) {
          debugPrint('📢 Opening channel: $channelId');
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => ChatWindowScreen(
                chatId: channelId,
                otherUserId: '',
              ),
            ),
          );
        }
        return;
      }

      debugPrint('⚠️ Unhandled deep link: $uri');
    });
  }

  String? _extractId(String path, String host, String type) {
    if (host == type) {
      return path.replaceFirst('/', '');
    }
    
    if (path.startsWith('/$type/')) {
      return path.replaceFirst('/$type/', '').replaceAll('/', '');
    }
    
    return null;
  }

  Map<String, String> _parseParams(Uri uri) {
    Map<String, String> params = {};
    params.addAll(uri.queryParameters);
    if (uri.fragment.isNotEmpty) {
      final fragmentParams = Uri.splitQueryString(uri.fragment);
      params.addAll(fragmentParams);
    }
    return params;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'KAPILA Learning',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      themeMode: t.isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF7B4FD6),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7B4FD6),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFEEF0FF),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF7B4FD6),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7B4FD6),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFF0B0E1A),
      ),
      home: const AuthWrapper(),
      routes: {
        '/global_search':   (context) => const GlobalSearchScreen(),
        '/create_post':     (context) => const CreatePostScreen(),
        '/contacts':        (context) => const ContactsScreen(),
        '/saved_messages':  (context) => const SavedMessagesScreen(),
        '/new_group':       (context) => const NewGroupScreen(),
        '/new_channel':     (context) => const NewChannelScreen(),
        '/create_story':    (context) => const CreateStoryScreen(),
        '/all_stories':     (context) => const AllStoriesScreen(),
        '/settings':        (context) => const SettingsScreen(),
        '/reset_password':  (context) => const ResetPasswordScreen(),
        '/user_profile': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return UserProfileScreen(
            userId: args['userId'] as String,
          );
        },
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
          final event = snapshot.data!.event;
          if (event == AuthChangeEvent.passwordRecovery) {
            return const ResetPasswordScreen();
          }
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

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final _chatService = ChatService();

  final List<Widget> _screens = [
    const HomeScreen(),
    const PerformanceScreen(),
    const PostsScreen(),
    const ChatListScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chatService.updateOnlineStatus(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatService.updateOnlineStatus(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('🟢 App resumed - Setting online');
        _chatService.updateOnlineStatus(true);
        break;
      case AppLifecycleState.paused:
        debugPrint('🔴 App paused - Setting offline');
        _chatService.updateOnlineStatus(false);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        debugPrint('🔴 App inactive/detached - Setting offline');
        _chatService.updateOnlineStatus(false);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E1A),
      extendBody: true,
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