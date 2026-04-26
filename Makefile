# Usage: make tag VERSION=1.0.2
tag:
	@test -n "$(VERSION)" || (echo "Error: VERSION is required. Usage: make tag VERSION=1.0.2" && exit 1)
	git tag v$(VERSION)
	git push origin v$(VERSION)
	@echo "Tagged and pushed v$(VERSION)"

APP_DIR := CometCursorApp
BUILD_SCRIPT := ../scripts/build.sh
APP_BUNDLE_NAME := Comet Cursor.app

# Build app bundle for local testing.
build-test:
	cd "$(APP_DIR)" && "$(BUILD_SCRIPT)"
	@echo "Test build completed."

# Launch the built app bundle.
run-test:
	open "$(APP_DIR)/$(APP_BUNDLE_NAME)"
	@echo "Launched Comet Cursor.app"

# Build and then launch in one command.
test: build-test run-test
