import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:hh_screen_recorder/hh_screen_recorder.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  String _platformVersion = 'Unknown';
  final _hhScreenRecorderPlugin = HhScreenRecorder();
  late final AnimationController _controller;
  late final Animation<double> _animation;

  Timer? _timer;
  Duration _elapsedTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    initPlatformState();

    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

    _animation = Tween<double>(begin: 0, end: 200).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Start the timer to track elapsed time
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedTime += const Duration(seconds: 1);
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel(); // Stop the timer
    super.dispose();
  }

  Future<void> initPlatformState() async {
    String platformVersion;
    try {
      platformVersion = await _hhScreenRecorderPlugin.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    String formattedTime = _elapsedTime.toString().split('.').first.padLeft(8, "0");

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Plugin example app')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Running on: $_platformVersion\n'),
              const SizedBox(height: 20),
              Text('Elapsed Time: $formattedTime', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  _hhScreenRecorderPlugin.startHighlight();
                },
                child: const Text('StartRecording'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  _hhScreenRecorderPlugin.endHighlight();
                },
                child: const Text('EndRecording'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  _hhScreenRecorderPlugin.saveHighlight("title", 2, []);
                },
                child: const Text('SaveRecording'),
              ),
              const SizedBox(height: 40),
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Container(
                    width: 220,
                    height: 10,
                    alignment: Alignment.centerLeft,
                    child: Container(width: _animation.value, height: 10, color: Colors.blue),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
