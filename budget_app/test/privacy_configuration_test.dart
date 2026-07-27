import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release configuration does not bundle an AI key or cloud AI client',
      () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('flutter_dotenv')));
    expect(pubspec, isNot(contains('dart_openai')));
    expect(pubspec, isNot(contains('\n    - .env')));

    final source = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');
    expect(source, isNot(contains('package:dart_openai')));
    expect(source, isNot(contains('package:flutter_dotenv')));
    expect(source, isNot(contains('OPEN_AI_API_KEY')));
  });

  test('production manifests do not request network or microphone access', () {
    final android =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final ios = File('ios/Runner/Info.plist').readAsStringSync();

    expect(android, isNot(contains('android.permission.INTERNET')));
    expect(android, isNot(contains('android.permission.RECORD_AUDIO')));
    expect(ios, isNot(contains('NSMicrophoneUsageDescription')));
  });

  test('iOS explains why file imports may access the camera', () {
    final ios = File('ios/Runner/Info.plist').readAsStringSync();

    expect(ios, contains('<key>NSCameraUsageDescription</key>'));
    expect(
      ios,
      contains(
        'Budgie uses the camera only when you choose to capture a file for '
        'importing financial data.',
      ),
    );
  });
}
