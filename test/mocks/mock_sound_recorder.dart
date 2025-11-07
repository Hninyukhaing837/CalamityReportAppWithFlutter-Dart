import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';

class MockFlutterSoundRecorder extends FlutterSoundRecorder {
  bool _isRecording = false;
  
  MockFlutterSoundRecorder() : super();
  
  @override
  Future<FlutterSoundRecorder?> openRecorder({
    dynamic isBGService = false,
  }) async {
    // Mock implementation
    return this;
  }

  @override
  Future<void> closeRecorder() async {
    // Mock implementation
    _isRecording = false;
    return;
  }

  @override
  Future<void> startRecorder({
    String? toFile,
    Codec codec = Codec.aacADTS,
    int? sampleRate,
    int numChannels = 1,
    int bitRate = 16000,
    int bufferSize = 8192,
    bool enableVoiceProcessing = false,
    AudioSource audioSource = AudioSource.defaultSource,
    StreamSink<Uint8List>? toStream,
    StreamSink<List<Float32List>>? toStreamFloat32,
    StreamSink<List<Int16List>>? toStreamInt16,
  }) async {
    // Mock implementation
    _isRecording = true;
    return;
  }

  @override
  Future<String?> stopRecorder() async {
    // Mock implementation
    _isRecording = false;
    return 'mock_recording.aac';
  }

  @override
  bool get isRecording => _isRecording;
  
  @override
  Future<bool> isEncoderSupported(Codec codec) async {
    return true;
  }
}