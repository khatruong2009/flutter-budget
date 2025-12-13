# Implementation Plan

- [x] 1. Set up design system foundation

  - Update color system to use solid colors instead of gradients for backgrounds
  - Keep typography system with text styles (already complete)
  - Keep animation system with curves and durations (already complete)
  - Update design_system.dart to remove glassmorphism helpers and add elevation helpers
  - _Requirements: 1.1, 1.2, 1.3_

- [ ]\* 1.1 Write property test for design token usage

  - **Property 1: Design token usage for spacing**
  - **Validates: Requirements 1.1, 1.2, 9.1**

- [ ]\* 1.2 Write property test for color token usage

  - **Property 2: Design token usage for colors**
  - **Validates: Requirements 1.1, 1.2**

- [ ]\* 1.3 Write property test for typography consistency

  - **Property 3: Typography consistency**
  - **Validates: Requirements 1.3**

- [x] 2. Create base elevated card component

  - Implement ElevatedCard widget with Material elevation
  - Add elevation, color, and border radius customization
  - Support tap interactions and padding
  - Replace existing GlassCard with ElevatedCard
  - _Requirements: 2.2, 2.3_

- [ ]\* 2.1 Write property test for elevation shadows

  - **Property 7: Elevation shadows on cards**
  - **Validates: Requirements 2.2**

- [ ]\* 2.2 Write property test for card border radius

  - **Property 8: Consistent border radius on cards**
  - **Validates: Requirements 2.3**

- [x] 3. Create enhanced button components

  - Implement primary button with solid color and elevation shadow
  - Implement secondary button with transparent background and border
  - Add loading state support
  - Add icon support with proper spacing
  - Support disabled state with reduced opacity
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

- [ ]\* 3.1 Write property test for primary button styling

  - **Property 15: Primary button styling**
  - **Validates: Requirements 4.1**

- [ ]\* 3.2 Write property test for secondary button styling

  - **Property 16: Secondary button styling**
  - **Validates: Requirements 4.2**

- [ ]\* 3.3 Write property test for button interaction feedback

  - **Property 12: Button interaction feedback**
  - **Validates: Requirements 3.3, 4.3**

- [ ]\* 3.4 Write property test for disabled button state

  - **Property 17: Disabled button state**
  - **Validates: Requirements 4.4**

- [ ]\* 3.5 Write property test for button icon spacing

  - **Property 18: Button icon spacing**
  - **Validates: Requirements 4.5**

- [ ]\* 3.6 Write property test for minimum touch target size

  - **Property 4: Minimum touch target size**
  - **Validates: Requirements 1.4**

- [x] 4. Create animated metric card component

  - Update AnimatedMetricCard to use ElevatedCard instead of GlassCard
  - Change gradient icon container to solid color
  - Keep AnimatedDigitWidget for value display (already complete)
  - Keep tap interactions (already complete)
  - _Requirements: 2.2, 3.2_

- [ ]\* 4.1 Write property test for animated number displays

  - **Property 11: Animated number displays**
  - **Validates: Requirements 3.2**

- [x] 5. Create modern transaction list item component

  - Update ModernTransactionListItem to use ElevatedCard instead of GlassCard
  - Change gradient icon container to solid color
  - Keep transaction details with proper typography (already complete)
  - Keep tap to edit functionality (already complete)
  - Keep Dismissible for swipe-to-delete (already complete)
  - _Requirements: 6.1, 6.2, 6.3_

- [ ]\* 5.1 Write property test for semantic color usage

  - **Property 5: Semantic color usage for financial data**
  - **Validates: Requirements 2.5, 6.2**

- [ ]\* 5.2 Write property test for category icon backgrounds

  - **Property 9: Category icon backgrounds**
  - **Validates: Requirements 6.3**

- [ ]\* 5.3 Write property test for list item animations

  - **Property 13: List item animations**
  - **Validates: Requirements 3.4**

- [x] 6. Create empty state component

  - Implement EmptyState widget with icon/illustration
  - Add helpful message text
  - Add call-to-action button
  - Support different empty state types (no data, no results, error)
  - _Requirements: 5.5, 10.1, 10.4_

- [x] 7. Create loading shimmer component

  - Implement LoadingShimmer widget with animated gradient
  - Create skeleton layouts for different content types
  - Add shimmer animation effect
  - _Requirements: 3.5, 10.2_

- [x] 8. Modernize SpendingPage

  - Add clean background with subtle color
  - Replace income/expense cards with AnimatedMetricCard
  - Enhance cash flow display with animations
  - Modernize month selector with better styling
  - Replace basic buttons with enhanced AppButton components
  - _Requirements: 2.1, 2.2, 3.2, 4.1_

- [ ]\* 8.1 Write property test for clean backgrounds

  - **Property 6: Clean backgrounds on screens**
  - **Validates: Requirements 2.1**

- [ ]\* 8.2 Write property test for section spacing

  - **Property 28: Section spacing consistency**
  - **Validates: Requirements 9.2**

- [x] 9. Modernize TransactionPage

  - Update background from gradient to clean solid color
  - Update ModernTransactionListItem usage (depends on task 5)
  - Change swipe-to-delete background from gradient to solid color
  - Keep empty state (already complete)
  - Keep list spacing and padding (already complete)
  - _Requirements: 2.1, 6.1, 6.2, 6.3, 10.1_

- [ ]\* 9.1 Write property test for list scroll padding

  - **Property 30: List scroll padding**
  - **Validates: Requirements 9.4**

- [x] 10. Modernize CategoryPage

  - Update background from gradient to clean solid color
  - Change pie chart from gradients to solid colors
  - Keep chart rendering animation (already complete)
  - Update legend list items to use ElevatedCard instead of GlassCard
  - Keep empty state (already complete)
  - Keep chart touch interactions (already complete)
  - _Requirements: 2.1, 5.1, 5.3, 5.4, 5.5_

- [ ]\* 10.1 Write property test for pie chart colors

  - **Property 19: Pie chart colors**
  - **Validates: Requirements 5.1**

- [ ]\* 10.2 Write property test for chart interactivity

  - **Property 20: Chart interactivity**
  - **Validates: Requirements 5.3**

- [ ]\* 10.3 Write property test for chart rendering animation

  - **Property 14: Chart rendering animation**
  - **Validates: Requirements 5.4**

- [x] 11. Modernize HistoryPage

  - Update background from gradient to clean solid color
  - Keep grouped transaction list with date headers (already complete)
  - Update ModernTransactionListItem usage (depends on task 5)
  - Keep sticky section headers (already complete)
  - Keep empty state (already complete)
  - _Requirements: 2.1, 6.5, 10.1_

- [ ]\* 11.1 Write property test for grouped list headers

  - **Property 27: Collapsing header implementation**
  - **Validates: Requirements 8.5**

- [x] 12. Modernize InsightsPage

  - Update background from gradient to clean solid color
  - Update metric cards to use ElevatedCard (depends on task 4)
  - Keep animated charts for trends (already complete)
  - Update insight cards to use ElevatedCard instead of GlassCard
  - Keep empty state (already complete)
  - _Requirements: 2.1, 2.2, 5.2, 10.1_

- [ ]\* 12.1 Write property test for chart animations

  - **Property 14: Chart rendering animation**
  - **Validates: Requirements 5.4**

- [x] 13. Modernize SettingsPage

  - Update background from gradient to clean solid color
  - Keep settings sections with headers (already complete)
  - Keep toggle switches with modern styling (already complete)
  - Keep setting descriptions (already complete)
  - Keep spacing and layout (already complete)
  - _Requirements: 2.1, 11.1, 11.2, 11.3, 11.4_

- [ ]\* 13.1 Write property test for settings sections

  - **Property 31: Settings section headers**
  - **Validates: Requirements 11.1**

- [ ]\* 13.2 Write property test for settings descriptions

  - **Property 32: Settings description styling**
  - **Validates: Requirements 11.4**

- [x] 14. Enhance transaction form

  - Keep input fields with floating labels (already complete)
  - Keep focus animations (already complete)
  - Keep error display (already complete)
  - Update background from gradient to clean solid color
  - Keep dropdown styling (already complete)
  - Keep numeric keyboard configuration (already complete)
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [ ]\* 14.1 Write property test for input field styling

  - **Property 21: Input field floating labels**
  - **Validates: Requirements 7.1**

- [ ]\* 14.2 Write property test for input focus styling

  - **Property 22: Input field focus styling**
  - **Validates: Requirements 7.2**

- [ ]\* 14.3 Write property test for error display

  - **Property 23: Input field error display**
  - **Validates: Requirements 7.3**

- [ ]\* 14.4 Write property test for numeric keyboard

  - **Property 24: Numeric input keyboard**
  - **Validates: Requirements 7.5**

- [x] 15. Enhance navigation and tab bar

  - Keep tab bar styling (already complete)
  - Keep AppBar typography (already complete)
  - Update navigation bar backgrounds from gradients to clean solid colors
  - Keep page transition animations (already complete)
  - _Requirements: 8.1, 8.3, 3.1_

- [ ]\* 15.1 Write property test for tab bar states

  - **Property 25: Tab bar active state**
  - **Validates: Requirements 8.1**

- [ ]\* 15.2 Write property test for AppBar typography

  - **Property 26: AppBar typography consistency**
  - **Validates: Requirements 8.3**

- [ ]\* 15.3 Write property test for page transitions

  - **Property 10: Page transition animations**
  - **Validates: Requirements 3.1**

- [x] 16. Add micro-interactions and feedback

  - Implement haptic feedback for key interactions
  - Add hover states for desktop platforms
  - Implement long press gesture handling
  - Add scale animations on button press
  - _Requirements: 12.2, 12.4, 12.5_

- [ ]\* 16.1 Write property test for hover states

  - **Property 33: Hover state on desktop**
  - **Validates: Requirements 12.2**

- [ ]\* 16.2 Write property test for long press handling

  - **Property 34: Long press gesture handling**
  - **Validates: Requirements 12.4**

- [ ]\* 16.3 Write property test for haptic feedback

  - **Property 35: Haptic feedback on interactions**
  - **Validates: Requirements 12.5**

- [x] 17. Implement grid and list spacing consistency

  - Audit all GridView widgets for spacing consistency
  - Audit all ListView widgets for padding
  - Ensure all gaps use design system constants
  - _Requirements: 9.3, 9.4_

- [ ]\* 17.1 Write property test for grid spacing

  - **Property 29: Grid spacing consistency**
  - **Validates: Requirements 9.3**

- [x] 18. Add dark mode enhancements

  - Update color adjustments for dark mode (solid colors instead of gradients)
  - Re-test contrast ratios in dark mode
  - Ensure elevated cards work properly in dark mode
  - Update color palette for dark theme
  - _Requirements: 1.5_

- [x] 19. Checkpoint - Ensure all tests pass

  - Ensure all tests pass, ask the user if questions arise.

- [x] 20. Performance optimization

  - Keep RepaintBoundary for animated widgets (already complete)
  - Re-optimize card rendering with const constructors for ElevatedCard
  - Re-profile animations with DevTools
  - Keep list rendering optimizations (already complete)
  - _Requirements: All_

- [ ]\* 20.1 Write performance tests for animations

  - Verify animations run at 60fps
  - Test with large datasets

- [x] 21. Accessibility audit

  - Re-verify touch targets with new ElevatedCard components
  - Re-test color contrast ratios with solid colors (WCAG AA)
  - Keep semantic labels (already complete)
  - Re-test keyboard navigation on desktop
  - _Requirements: 1.4, All_

- [ ]\* 21.1 Write accessibility tests

  - Test touch target sizes
  - Test contrast ratios
  - Test screen reader labels

- [x] 22. Platform-specific enhancements

  - Re-test iOS-specific styling with new design
  - Re-test Android-specific styling with new design
  - Keep desktop hover states and keyboard navigation (already complete)
  - Re-test web responsiveness
  - _Requirements: All_

- [x] 23. Final polish and refinement

  - Review all screens for consistency with new Material Design approach
  - Keep animation timings (already complete)
  - Keep spacing and alignment (already complete)
  - Re-test on multiple devices and screen sizes
  - Gather feedback and iterate
  - _Requirements: All_

- [x] 24. Final Checkpoint - Ensure all tests pass

  - Ensure all tests pass, ask the user if questions arise.

- [x] 25. Bug fixes and UI refinements
  - Fix month selector to show current month by default on SpendingPage
  - Increase brightness of income/expenses text for better visibility
  - Revert to old dock/tab selector style (iOS-style dock with floating appearance)
  - Fix overflow issues on categories and history pages
  - Fix NumberFormat display issues showing "NumberFormat" instead of formatted numbers
  - _Requirements: 2.1, 2.2, 8.1_
