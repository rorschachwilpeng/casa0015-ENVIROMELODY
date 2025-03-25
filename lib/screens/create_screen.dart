import 'package:flutter/material.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({Key? key}) : super(key: key);

  @override
  _CreateScreenState createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final TextEditingController _promptController = TextEditingController();
  bool _isGenerating = false;
  String? _generatedMusicUrl;
  
  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }
  
  Future<void> _generateMusic() async {
    setState(() {
      _isGenerating = true;
      _generatedMusicUrl = null;
    });
    
    // TODO: Implement Suno API call
    
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 2));
    
    setState(() {
      _isGenerating = false;
      _generatedMusicUrl = "https://example.com/sample-music.mp3";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Music'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _promptController,
              decoration: const InputDecoration(
                labelText: 'Describe the music you want',
                hintText: 'Example: A relaxing jazz music with piano and saxophone',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isGenerating ? null : _generateMusic,
              child: _isGenerating 
                ? const CircularProgressIndicator() 
                : const Text('Generate Music'),
            ),
            const SizedBox(height: 20),
            if (_generatedMusicUrl != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text('Generation Complete!'),
                      TextButton(
                        onPressed: () {
                          // TODO: Implement music playback
                        },
                        child: const Text('Play Music'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 