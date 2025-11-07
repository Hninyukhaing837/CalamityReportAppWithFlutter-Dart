import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final TextEditingController _messageController = TextEditingController();
  bool _isRecording = false;
  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    initializeRecorder();
  }

  Future<void> initializeRecorder() async {
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw RecordingPermissionException('Microphone permission required');
      }
      await _recorder.openRecorder();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error initializing recorder: $e');
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      await _recorder.startRecorder(
        toFile: 'audio_message.aac',
        codec: Codec.aacADTS,
      );
      setState(() => _isRecording = true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error starting recording: $e');
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      String? path = await _recorder.stopRecorder();
      setState(() {
        _isRecording = false;
        _messages.add(ChatMessage(
          isAudio: true,
          content: path ?? '',
          timestamp: DateTime.now(),
        ));
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error stopping recording: $e');
      }
    }
  }

  void _sendTextMessage() {
    if (_messageController.text.isNotEmpty) {
      setState(() {
        _messages.add(ChatMessage(
          isAudio: false,
          content: _messageController.text,
          timestamp: DateTime.now(),
        ));
        _messageController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Chat'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[_messages.length - 1 - index];
                return ListTile(
                  leading: Icon(
                    message.isAudio ? Icons.mic : Icons.message,
                  ),
                  title: Text(
                    message.isAudio ? 'Voice Message' : message.content,
                  ),
                  subtitle: Text(
                    message.timestamp.toString(),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onLongPressStart: (_) => _startRecording(),
                  onLongPressEnd: (_) => _stopRecording(),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.red : Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isRecording ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendTextMessage,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _messageController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final bool isAudio;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.isAudio,
    required this.content,
    required this.timestamp,
  });
}
//Text messaging functionality
//Walkie-talkie feature (press and hold to record)
//Message history display
//Microphone permission handling
//Audio recording using Flutter Sound