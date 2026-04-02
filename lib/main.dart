import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/dashboard_screen.dart';
import 'screens/device_lab_screen.dart';
import 'screens/live_stream_screen.dart';
import 'screens/report_screen.dart';
import 'screens/field_map_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: AgriDroneApp()));
}

class AgriDroneTheme {
  static const Color background = Color(0xFF0A0F0D);
  static const Color surface = Color(0xFF1A2A1E);
  static const Color primaryAccent = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFFB923C);
  static const Color danger = Color(0xFFF87171);
  static const Color textPrimary = Color(0xFFE8F5E9);
  static const Color textSecondary = Color(0xFF86A98E);
  static final Color borderHighlight = const Color(
    0xFF4ADE80,
  ).withOpacity(0.15);

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primaryAccent,
      colorScheme: ColorScheme.dark(
        primary: primaryAccent,
        surface: surface,
        background: background,
        error: danger,
        onPrimary: Colors.black,
        onSurface: textPrimary,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.syne(
          fontWeight: FontWeight.w800,
          color: textPrimary,
          fontSize: 36,
          letterSpacing: -1.0,
        ),
        displayMedium: GoogleFonts.syne(
          fontWeight: FontWeight.w800,
          color: textPrimary,
          fontSize: 28,
          letterSpacing: -0.5,
        ),
        displaySmall: GoogleFonts.syne(
          fontWeight: FontWeight.w800,
          color: textPrimary,
          fontSize: 22,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.syne(
          fontWeight: FontWeight.w700,
          color: textPrimary,
          fontSize: 20,
        ),
        headlineSmall: GoogleFonts.syne(
          fontWeight: FontWeight.w700,
          color: textPrimary,
          fontSize: 18,
        ),
        titleLarge: GoogleFonts.syne(
          fontWeight: FontWeight.w800,
          color: textPrimary,
          fontSize: 16,
          letterSpacing: 0.5,
        ),
        bodyLarge: GoogleFonts.instrumentSans(
          fontWeight: FontWeight.w500,
          color: textPrimary,
          fontSize: 18,
        ),
        bodyMedium: GoogleFonts.instrumentSans(
          fontWeight: FontWeight.w400,
          color: textPrimary,
          fontSize: 16,
          letterSpacing: 0.2,
        ),
        bodySmall: GoogleFonts.instrumentSans(
          fontWeight: FontWeight.w400,
          color: textSecondary,
          fontSize: 13,
          letterSpacing: 0.3,
        ),
        labelLarge: GoogleFonts.dmMono(
          fontWeight: FontWeight.w500,
          color: textPrimary,
          fontSize: 18,
          letterSpacing: 1.0,
        ),
        labelMedium: GoogleFonts.dmMono(
          fontWeight: FontWeight.w400,
          color: textPrimary,
          fontSize: 14,
          letterSpacing: 0.8,
        ),
        labelSmall: GoogleFonts.dmMono(
          fontWeight: FontWeight.w500,
          color: textSecondary,
          fontSize: 11,
          letterSpacing: 1.2,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.syne(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          color: textPrimary,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primaryAccent.withOpacity(0.2),
        labelTextStyle: MaterialStateProperty.all(
          GoogleFonts.instrumentSans(
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: textPrimary,
          ),
        ),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const IconThemeData(color: primaryAccent);
          }
          return const IconThemeData(color: textSecondary);
        }),
      ),
    );
  }
}

class AgriDroneApp extends StatelessWidget {
  const AgriDroneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AgriDrone Guardian',
      theme: AgriDroneTheme.themeData,
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    LiveStreamScreen(),
    DeviceLabScreen(),
    ReportScreen(),
    FieldMapScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1A10),
          border: Border(
            top: BorderSide(
              color: const Color(0xFF4ADE80).withOpacity(0.15),
              width: 1.0,
            ),
          ),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            backgroundColor: Colors.transparent,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            selectedItemColor: const Color(0xFF4ADE80),
            unselectedItemColor: const Color(0xFF4A6B51),
            selectedLabelStyle: Theme.of(context).textTheme.labelSmall
                ?.copyWith(
                  color: const Color(0xFF4ADE80),
                  fontWeight: FontWeight.bold,
                ),
            unselectedLabelStyle: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: const Color(0xFF4A6B51)),
            items: [
              _buildBottomNavItem(
                0,
                Icons.dashboard_outlined,
                Icons.dashboard,
                'Dashboard',
              ),
              _buildBottomNavItem(
                1,
                Icons.videocam_outlined,
                Icons.videocam,
                'Live',
              ),
              _buildBottomNavItem(
                2,
                Icons.science_outlined,
                Icons.science,
                'Lab',
              ),
              _buildBottomNavItem(
                3,
                Icons.analytics_outlined,
                Icons.analytics,
                'Report',
              ),
              _buildBottomNavItem(4, Icons.map_outlined, Icons.map, 'Map'),
              _buildBottomNavItem(
                5,
                Icons.settings_outlined,
                Icons.settings,
                'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildBottomNavItem(
    int index,
    IconData outline,
    IconData filled,
    String label,
  ) {
    final isActive = _currentIndex == index;
    final color = isActive ? const Color(0xFF4ADE80) : const Color(0xFF4A6B51);

    return BottomNavigationBarItem(
      icon: Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? filled : outline, color: color),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Color(0xFF4ADE80),
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(height: 8), // match height to prevent jumping
          ],
        ),
      ),
      label: label,
    );
  }
}
