import 'package:flutter/material.dart';
import '../utils/deepseek_test.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Mock user data
    const String username = "Music Lover";
    const String email = "music_lover@example.com";
    const int createdMusicCount = 15;
    const int favoriteMusicCount = 8;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 60,
              backgroundColor: Colors.blue,
              child: Icon(
                Icons.person,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              username,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              email,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.music_note),
              title: const Text('My Created Music'),
              trailing: Text(
                '$createdMusicCount',
                style: const TextStyle(fontSize: 18),
              ),
              onTap: () {
                // TODO: Navigate to user created music list
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('My Favorite Music'),
              trailing: Text(
                '$favoriteMusicCount',
                style: const TextStyle(fontSize: 18),
              ),
              onTap: () {
                // TODO: Navigate to user favorite music list
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                // TODO: Navigate to settings page
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cloud),
              title: const Text('测试 DeepSeek API'),
              onTap: () {
                testDeepSeekApi(context);
              },
            ),
            const Divider(),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement logout functionality
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
} 