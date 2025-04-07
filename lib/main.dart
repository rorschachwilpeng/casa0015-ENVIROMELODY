import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/create_screen.dart';
import 'screens/library_screen.dart';
import 'screens/profile_screen.dart';
import 'services/music_library_manager.dart';
import 'services/audio_player_manager.dart';
import 'widgets/mini_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialization of services
  await MusicLibraryManager().initialize();
  
  // Ensure AudioPlayerManager is created
  AudioPlayerManager();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    // Use the public method to release resources
    AudioPlayerManager().disposePlayer();
    
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // When the app goes to the background, pause the music
      AudioPlayerManager().pauseMusic();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoundScape',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  static const List<Widget> _pages = [
    HomeScreen(),
    CreateScreen(),
    LibraryScreen(),
    ProfileScreen(),
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini player
          const MiniPlayer(),
          // Bottom navigation bar
          BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            // Set background color
            backgroundColor: Colors.black,
            
            // Set selected item color
            selectedItemColor: Colors.blue,
            
            // Set unselected item color
            unselectedItemColor: Colors.grey,
            
            // Set selected item icon color
            selectedIconTheme: const IconThemeData(color: Colors.blue),
            
            // Set unselected item icon color
            unselectedIconTheme: const IconThemeData(color: Colors.grey),
            
            // Set selected item text style
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
            
            // Set unselected item text style
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
            
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.add),
                label: 'Create',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.library_music),
                label: 'Library',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Settings',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
