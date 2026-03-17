import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'providers/app_provider.dart';
import 'screens/home_screen.dart';
import 'screens/result_screen.dart';
import 'screens/soil_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/developer_screen.dart';
import 'widgets/status_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const AgriDroneApp());
}

class AgriDroneApp extends StatelessWidget {
  const AgriDroneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider()..init(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'AgriDrone Guardian',
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            brightness: Brightness.light,
            seedColor: const Color(0xFF2E7D32),
            primary: const Color(0xFF2E7D32),
            secondary: const Color(0xFF4CAF50),
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: const Color(0xFFF5FFFA),
          textTheme: GoogleFonts.poppinsTextTheme().apply(
            bodyColor: const Color(0xFF1B3A1E),
            displayColor: const Color(0xFF1B3A1E),
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFF2E7D32).withValues(alpha: 0.15),
            labelTextStyle: MaterialStateProperty.all(
              const TextStyle(color: Color(0xFF2E7D32), fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
          navigationRailTheme: NavigationRailThemeData(
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFF2E7D32).withValues(alpha: 0.1),
            selectedIconTheme: const IconThemeData(color: Color(0xFF2E7D32)),
            unselectedIconTheme: const IconThemeData(color: Color(0xFF9E9E9E)),
            selectedLabelTextStyle: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
            unselectedLabelTextStyle: const TextStyle(color: Color(0xFF9E9E9E)),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Color(0xFF1B3A1E),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: const Color(0xFF2E7D32).withValues(alpha: 0.12)),
            ),
            elevation: 0,
          ),
        ),
        home: const AppShell(),
        routes: {
          SettingsScreen.route: (_) => const SettingsScreen(),
          DeveloperScreen.route: (_) => const DeveloperScreen(),
        },
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  final screens = const [
    HomeScreen(),
    ResultScreen(),
    SoilScreen(),
    DeveloperScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWeb = width >= 600;

    return Scaffold(
      body: Row(
        children: [
          if (isWeb)
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: (i) => setState(() => index = i),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    const Icon(Icons.radar, color: Color(0xFF2E7D32), size: 28),
                    const SizedBox(height: 2),
                    const Text('AG', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                  ],
                ),
              ),
              destinations: [
                const NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: Text('Home'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.analytics_outlined),
                  selectedIcon: Icon(Icons.analytics),
                  label: Text('Results'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.water_drop_outlined),
                  selectedIcon: Icon(Icons.water_drop),
                  label: Text('Soil'),
                ),
                if (context.watch<AppProvider>().isDevMode)
                  const NavigationRailDestination(
                    icon: Icon(Icons.bug_report_outlined),
                    selectedIcon: Icon(Icons.bug_report),
                    label: Text('Dev'),
                  ),
              ],
            ),
          Expanded(
            child: Column(
              children: [
                const StatusBar(),
                Expanded(child: screens[index]),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWeb
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => setState(() => index = i),
              destinations: [
                const NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
                const NavigationDestination(
                    icon: Icon(Icons.analytics), label: 'Results'),
                const NavigationDestination(
                    icon: Icon(Icons.water_drop), label: 'Soil'),
                if (context.watch<AppProvider>().isDevMode)
                  const NavigationDestination(
                    icon: Icon(Icons.bug_report), label: 'Developer'),
              ],
            ),
    );
  }
}
