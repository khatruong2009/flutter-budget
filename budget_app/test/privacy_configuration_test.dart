import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release configuration enables the explicitly accepted OpenAI flow', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('flutter_dotenv'));
    expect(pubspec, contains('dart_openai'));
    expect(pubspec, contains('\n    - .env'));

    final source = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');
    expect(source, contains('package:dart_openai'));
    expect(source, contains('package:flutter_dotenv'));
    expect(source, contains('OPEN_AI_API_KEY'));

    final gitignore = File('../.gitignore').readAsStringSync();
    expect(gitignore, contains('budget_app/.env'));
  });

  test('voice entry declares microphone and network access', () {
    final android =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final ios = File('ios/Runner/Info.plist').readAsStringSync();

    expect(android, contains('android.permission.RECORD_AUDIO'));
    expect(android, contains('android.permission.INTERNET'));
    expect(ios, contains('NSMicrophoneUsageDescription'));
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
