import 'package:flutter_test/flutter_test.dart';
import 'package:budget_app/utils/micro_interactions.dart';

void main() {
  group('MicroInteractions', () {
    test('platform detection methods return boolean values', () {
      // These should not throw and should return boolean values
      expect(MicroInteractions.isDesktop(), isA<bool>());
      expect(MicroInteractions.isMobile(), isA<bool>());
      expect(MicroInteractions.isWeb(), isA<bool>());
      expect(MicroInteractions.shouldEnableHover(), isA<bool>());
    });

    test('haptic feedback methods complete without error', () async {
      // These should complete without throwing errors
      // On platforms without haptic support, they should silently succeed
      await expectLater(
        MicroInteractions.lightImpact(),
        completes,
      );
      
      await expectLater(
        MicroInteractions.mediumImpact(),
        completes,
      );
      
      await expectLater(
        MicroInteractions.heavyImpact(),
        completes,
      );
      
      await expectLater(
        MicroInteractions.selectionClick(),
        completes,
      );
      
      await expectLater(
        MicroInteractions.vibrate(),
        completes,
      );
    });

    test('platform detection is consistent', () {
      // Only one platform type should be true at a time
      final isDesktop = MicroInteractions.isDesktop();
      final isMobile = MicroInteractions.isMobile();
      final isWeb = MicroInteractions.isWeb();
      
      // At most one should be true (could all be false in test environment)
      final trueCount = [isDesktop, isMobile, isWeb].where((v) => v).length;
      expect(trueCount, lessThanOrEqualTo(1));
    });

    test('hover should be enabled on desktop or web', () {
      final shouldEnableHover = MicroInteractions.shouldEnableHover();
      final isDesktop = MicroInteractions.isDesktop();
      final isWeb = MicroInteractions.isWeb();
      
      // Hover should be enabled if desktop or web
      if (isDesktop || isWeb) {
        expect(shouldEnableHover, isTrue);
      }
    });
  });
}
