import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AudioVisualizer extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final Color color;
  final Color backgroundColor;
  
  const AudioVisualizer({
    Key? key,
    required this.audioPlayer,
    this.color = Colors.blue,
    this.backgroundColor = Colors.black12,
  }) : super(key: key);

  @override
  _AudioVisualizerState createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer> with SingleTickerProviderStateMixin {
  final List<double> _barHeights = List.filled(30, 0.0);
  final Random _random = Random();
  Timer? _timer;
  
  @override
  void initState() {
    super.initState();
    
    // print("AudioVisualizer: Initialize, Playback State=${widget.audioPlayer.playing}");
    
    // If already playing, start animation immediately
    if (widget.audioPlayer.playing) {
      _startAnimation();
    } else {
      _stopAnimation(); // Ensure initial state is stationary
    }
    
    // Listen for playback state changes
    widget.audioPlayer.playerStateStream.listen((state) {
      // print("AudioVisualizer: Playback State Changed ${state.playing}");
      if (state.playing) {
        _startAnimation();
      } else {
        _stopAnimation();
      }
    });
  }
  
  void _startAnimation() {
    // Cancel previous timer
    _timer?.cancel();
    
    // Check if playing
    // print("AudioVisualizer: Attempting to start animation, Playback State=${widget.audioPlayer.playing}");
    
    // If playing, start animation
    if (widget.audioPlayer.playing) {
      _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (mounted) {
          setState(() {
            // Generate random heights to simulate audio waveform based on current playback
            for (int i = 0; i < _barHeights.length; i++) {
              if (widget.audioPlayer.playing) {
                // Use random values to simulate audio waveform
                _barHeights[i] = _random.nextDouble() * 0.8 + 0.2;
              } else {
                _barHeights[i] = 0;
              }
            }
          });
        } else {
          timer.cancel();
        }
      });
    }
  }
  
  void _stopAnimation() {
    _timer?.cancel();
    if (mounted) {
      setState(() {
        for (int i = 0; i < _barHeights.length; i++) {
          _barHeights[i] = 0;
        }
      });
    }
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 45, // Decrease height, consistent with the above setting
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Decrease padding
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_barHeights.length, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 3, // Decrease width
            height: _barHeights[index] * 35, // Decrease maximum height
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.6 + _barHeights[index] * 0.4),
              borderRadius: BorderRadius.circular(1.5),
            ),
          );
        }),
      ),
    );
  }
} 