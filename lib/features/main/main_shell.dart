import 'package:flutter/material.dart';
import '../workspace/workspace_screen.dart';
import '../flashcards/flashcard_screen.dart';
import '../study_pod/study_pod_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    WorkspaceScreen(),
    FlashcardScreen(),
    StudyPodScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.folder_open_rounded),
            selectedIcon: Icon(Icons.folder_rounded),
            label: 'Workspace',
          ),
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style_rounded),
            label: 'Flashcards',
          ),
          NavigationDestination(
            icon: Icon(Icons.podcasts_outlined),
            selectedIcon: Icon(Icons.podcasts_rounded),
            label: 'Study Pod',
          ),
        ],
      ),
    );
  }
}
