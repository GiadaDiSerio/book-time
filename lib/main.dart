import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'views/pages/search_page.dart';
import 'views/pages/timer_page.dart';
import 'controllers/app_controller.dart';
import 'views/pages/profile_tab.dart';
import 'views/dialogs/settings_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appController = AppController();
  await appController.loadState();
  runApp(
    ChangeNotifierProvider(
      create: (context) => appController,
      child: const BookTimeApp(),
    ),
  );
}

class BookTimeApp extends StatelessWidget {
  const BookTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appController = context.watch<AppController>();
    return MaterialApp(
      title: 'Book Time',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: appController.themeMode,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0; // Default: Profilo

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appController = context.read<AppController>();
      if (appController.isFirstLaunch) {
        _showWelcomeDialog();
      }
    });
  }

  // Dialog di benvenuto al primo avvio
  void _showWelcomeDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Benvenuto su Book Time! 📚'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Username:',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Username',
                hintText: 'Es: mariorossi',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.person),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                context.read<AppController>().setUserName(name);
                Navigator.pop(dialogContext);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('INIZIAMO!'),
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Book Time',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => showSettingsDialog(context),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          // Tab 0: Profilo
          ProfileTab(),
          // Tab 1: Esplora
          SearchPage(),
          // Tab 2: Timer
          TimerPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profilo',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Esplora',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timer),
            label: 'Timer',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        onTap: _onItemTapped,
      ),
    );
  }
}
