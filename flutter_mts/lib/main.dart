import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/market_screen.dart';
import 'screens/portfolio_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/transfer_screen.dart'; 
import 'screens/transfer_history_screen.dart';
import 'providers/market_data_provider.dart';
import 'providers/user_provider.dart';
import 'providers/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MarketDataProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const MTSApp(),
    ),
  );
}

class MTSApp extends StatelessWidget {
  const MTSApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    
    return MaterialApp(
      title: 'MTS Premium',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(settings.fontSizeFactor),
          ),
          child: child!,
        );
      },
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        primaryColor: const Color(0xFF2D5AF7),
        cardColor: const Color(0xFFF5F7FF),
        canvasColor: const Color(0xFFF0F2F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2D5AF7),
          secondary: Color(0xFF00D2FF),
          surface: Color(0xFFF5F7FF),
          error: Color(0xFFFF4B4B),
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F111A),
        primaryColor: const Color(0xFF2D5AF7),
        cardColor: const Color(0xFF1A1D2D),
        canvasColor: const Color(0xFF161926),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F111A),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2D5AF7),
          secondary: Color(0xFF00D2FF),
          surface: Color(0xFF1A1D2D),
          error: Color(0xFFFF4B4B),
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          if (!userProvider.isAuthenticated) {
            return const LoginScreen();
          }
          return const MainNavigation();
        },
      ),
      routes: {
        '/transfer_history': (context) => const TransferHistoryScreen(),
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _screens.addAll([
      const HomeScreen(),
      const MarketScreen(),
      const PortfolioScreen(),
      const TransferScreen(), // 이체 탭 추가 (인덱스 3)
      SettingsScreen(onTabChange: (index) => setState(() => _selectedIndex = index)), // 설정 (인덱스 4)
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: _selectedIndex == 4 // 설정 화면(마지막 인덱스)에서만 숨김
        ? null 
        : NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) => setState(() => _selectedIndex = index),
            backgroundColor: Theme.of(context).canvasColor,
            indicatorColor: Theme.of(context).primaryColor.withOpacity(0.2),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '홈'),
              NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: '주식'),
              NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: '자산'),
              NavigationDestination(icon: Icon(Icons.swap_horiz_outlined), selectedIcon: Icon(Icons.swap_horiz), label: '이체'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), label: '설정'),
            ],
          ),
    );
  }
}
