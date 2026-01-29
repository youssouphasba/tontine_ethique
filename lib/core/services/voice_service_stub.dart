// Stub file for web builds where 'package:record' is not available.

class AudioRecorder {
  Future<bool> hasPermission() async => false;
  Future<void> start(RecordConfig config, {required String path}) async {}
  Future<String?> stop() async => null;
  Future<void> dispose() async {}
}

class RecordConfig {
  final AudioEncoder encoder;
  final int sampleRate;
  final int numChannels;
  
  const RecordConfig({
    this.encoder = AudioEncoder.wav, 
    this.sampleRate = 16000, 
    this.numChannels = 1
  });
}

enum AudioEncoder { 
  wav, 
  aacHe, 
  aacLc, 
  amrNb, 
  amrWb, 
  opus, 
  flac 
}
