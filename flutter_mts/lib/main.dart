import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/market_screen.dart';
import 'screens/portfolio_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/transfer_screen.dart'; // 이체 화면 임포트
import 'providers/market_data_provider.dart';
import 'providers/user_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MarketDataProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: const MTSApp(),
    ),
  );
}

class MTSApp extends StatelessWidget {
  const MTSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MTS Premium',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F111A),
        primaryColor: const Color(0xFF2D5AF7),
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
            backgroundColor: const Color(0xFF161926),
            indicatorColor: Colors.blue.withOpacity(0.2),
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
