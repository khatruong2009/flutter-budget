.PHONY: help setup get analyze test check format clean run run-web ios android update-goldens

help:
	@echo "Available targets:"
	@echo "  setup           flutter pub get"
	@echo "  analyze         flutter analyze"
	@echo "  test            flutter test"
	@echo "  check           analyze + test (matches CI)"
	@echo "  format          dart format ."
	@echo "  format-check    dart format --set-exit-if-changed ."
	@echo "  clean           flutter clean"
	@echo "  run             flutter run"
	@echo "  run-web         flutter run -d chrome"
	@echo "  update-goldens  flutter test --update-goldens"

setup get:
	flutter pub get

analyze:
	flutter analyze

test:
	flutter test

check: analyze test

format:
	dart format .

format-check:
	dart format --set-exit-if-changed .

clean:
	flutter clean

run:
	flutter run

run-web:
	flutter run -d chrome

update-goldens:
	flutter test --update-goldens
