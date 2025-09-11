.PHONY: help test test-unit test-integration coverage analyze format clean install publish-check

help:
	@echo "Available commands:"
	@echo "  make install         - Install dependencies"
	@echo "  make test           - Run all tests"
	@echo "  make test-unit      - Run unit tests only"
	@echo "  make test-integration - Run integration tests with emulator"
	@echo "  make coverage       - Generate test coverage report"
	@echo "  make analyze        - Run static analysis"
	@echo "  make format         - Format code"
	@echo "  make clean          - Clean build artifacts"
	@echo "  make publish-check  - Check if package is ready to publish"

install:
	dart pub get

test: test-unit test-integration

test-unit:
	dart test test/unit

test-integration:
	@echo "Starting Firestore emulator for integration tests..."
	firebase emulators:exec --only firestore --project test-project \
		"dart test test/integration" || true

coverage:
	dart test --coverage=coverage test/unit
	dart pub global activate coverage
	dart pub global run coverage:format_coverage \
		--lcov \
		--in=coverage \
		--out=coverage/lcov.info \
		--report-on=lib
	@echo "Coverage report generated at coverage/lcov.info"
	@echo "To view HTML report, run: genhtml coverage/lcov.info -o coverage/html"

analyze:
	dart analyze --fatal-infos

format:
	dart format .

clean:
	rm -rf .dart_tool
	rm -rf coverage
	rm -rf build
	rm -f pubspec.lock

publish-check:
	dart pub publish --dry-run