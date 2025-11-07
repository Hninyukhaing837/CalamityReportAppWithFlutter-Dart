import 'package:flutter_sound/flutter_sound.dart';
import 'dart:async';
import 'dart:typed_data';

abstract class MockFlutterSoundRecorder implements FlutterSoundRecorder {
  bool _isInitialized = false;

  @override
  Future<FlutterSoundRecorder?> openRecorder({dynamic isBGService}) async {
    _isInitialized = true;
    return this;
  }

  @override
  Future<void> closeRecorder() async {
    _isInitialized = false;
  }

  bool get isInitialized => _isInitialized;

  // Implement other required methods with mock behavior
  @override
  Future<void> startRecorder({
    String? toFile,
    Codec codec = Codec.aacADTS,
    int? sampleRate,
    int numChannels = 1,
    int bitRate = 32000,
    AudioSource audioSource = AudioSource.microphone,
    int bufferSize = 8192,
    bool enableVoiceProcessing = false,
    StreamSink<Uint8List>? toStream,
    StreamSink<List<Float32List>>? toStreamFloat32,
    StreamSink<List<Int16List>>? toStreamInt16,
  }) async {}

  @override
  Future<String?> stopRecorder() async => null;

  @override
  bool get isRecording => false;

  @override
  Future<void> setSubscriptionDuration(Duration duration) async {}

  @override
  Stream<RecordingDisposition>? get onProgress => null;
}