// Hosts the primary tab navigation and lazily retains each feature screen.

import 'package:flutter/material.dart';

import '../../../../features/pets/presentation/pages/pet_home_page.dart';
import '../../../../features/reminders/presentation/pages/reminders_page.dart';
import '../../../../features/visits/presentation/pages/visits_page.dart';
import '../../../../../features/more/presentation/pages/more_page.dart';

/// Owns the top-level tab shell and preserves initialized tabs.
class AppShellPage extends StatefulWidget {
  /// Creates the application's primary tab-navigation shell.
  const AppShellPage({super.key});

  /// Creates the state that manages the application tabs.
  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

/// Manages tab selection and lazily creates each tab while retaining visited screens.
class _AppShellPageState extends State<AppShellPage> {
  int _selectedIndex = 0;

  late final List<Widget?> _pages = [
    _HomeView(onOpenReminders: _showReminders, onOpenVisits: _showVisits),
    null,
    null,
    null,
  ];

  /// Returns the screen for a tab, creating it only when first selected.
  Widget _createPage(int index) {
    return switch (index) {
      1 => RemindersPage(onNotificationOpened: _showReminders),
      2 => const VisitsPage(),
      3 => const MorePage(),
      _ => throw RangeError.index(index, _pages),
    };
  }

  /// Selects a tab and lazily creates its screen on first use.
  void _selectPage(int index) {
    if (index == _selectedIndex) return;
    if (!mounted) return;
    setState(() {
      _selectedIndex = index;
      _pages[index] ??= _createPage(index);
    });
  }

  /// Selects the reminders tab when opened from another screen.
  void _showReminders() {
    _selectPage(1);
  }

  /// Selects the visits tab when opened from another screen.
  void _showVisits() {
    _selectPage(2);
  }

  /// Builds the widget tree for app shell page state.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [for (final page in _pages) page ?? const SizedBox.shrink()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectPage,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.alarm_outlined),
            selectedIcon: Icon(Icons.alarm),
            label: 'Reminders',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Visits',
          ),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}

/// Connects Home dashboard shortcuts to the corresponding application tabs.
class _HomeView extends StatelessWidget {
  final VoidCallback onOpenReminders;
  final VoidCallback onOpenVisits;

  /// Connects Home shortcut callbacks to their destination tabs.
  const _HomeView({required this.onOpenReminders, required this.onOpenVisits});

  /// Builds the widget tree for home view.
  @override
  Widget build(BuildContext context) {
    return PetHomePage(
      onOpenReminders: onOpenReminders,
      onOpenVisits: onOpenVisits,
    );
  }
}
