# =============================================================================
# OR Scheduler — Development Commands
# =============================================================================
#
# Quick start:
#   make setup      Install all dependencies
#   make dev        Start emulators + seed + app in one command
#
# Individual commands:
#   make emulators  Start Firebase emulators (background)
#   make seed       Seed test data into running emulators
#   make run        Run Flutter web app (connects to emulators on localhost)
#   make stop       Stop emulators
#   make clean      Stop everything and clean build artifacts
#
# Test credentials (after seeding):
#   doctor@test.com / password123
#   nurse@test.com  / password123
# =============================================================================

.PHONY: setup dev emulators seed run stop clean check test analyze

# --- Setup -------------------------------------------------------------------

setup: ## Install all dependencies
	@echo "Installing Flutter dependencies..."
	@flutter pub get
	@echo ""
	@echo "Checking Firebase CLI..."
	@which firebase > /dev/null 2>&1 || (echo "ERROR: Firebase CLI not found. Install with: npm install -g firebase-tools" && exit 1)
	@echo "Firebase CLI: $$(firebase --version)"
	@echo ""
	@echo "Checking Java (required for emulators)..."
	@which java > /dev/null 2>&1 || (echo "ERROR: Java not found. Install JDK 11+." && exit 1)
	@java -version 2>&1 | head -1
	@echo ""
	@cp -n .env.example .env 2>/dev/null || true
	@echo "Setup complete. Run 'make dev' to start developing."

# --- Development (all-in-one) ------------------------------------------------

dev: ## Start emulators, seed data, and run the app
	@$(MAKE) emulators
	@sleep 4
	@$(MAKE) seed
	@echo ""
	@echo "Starting Flutter web app..."
	@echo "The app will open at http://localhost:3000"
	@echo ""
	flutter run -d chrome --web-port 3000

# --- Emulators ---------------------------------------------------------------

emulators: ## Start Firebase emulators in background
	@echo "Starting Firebase emulators..."
	@echo "  Auth:      http://localhost:9099"
	@echo "  Firestore: http://localhost:8181"
	@echo "  Storage:   http://localhost:9199"
	@echo "  UI:        http://localhost:4000"
	@echo ""
	@firebase emulators:start --only auth,firestore,storage \
		--import=./emulator-data \
		--export-on-exit=./emulator-data \
		> .emulator.log 2>&1 &
	@echo "Emulators starting in background (log: .emulator.log)"
	@echo "Waiting for emulators to be ready..."
	@for i in $$(seq 1 30); do \
		if curl -s http://localhost:9099/ > /dev/null 2>&1; then \
			echo "Emulators ready!"; \
			break; \
		fi; \
		sleep 1; \
	done

seed: ## Seed test data into running emulators
	@node scripts/seed.js

seed-reset: ## Clear emulators and re-seed
	@node scripts/seed.js --reset

stop: ## Stop Firebase emulators
	@echo "Stopping emulators..."
	@pkill -f "firebase emulators" 2>/dev/null || true
	@pkill -f "java.*cloud-firestore-emulator" 2>/dev/null || true
	@echo "Emulators stopped."

# --- App ---------------------------------------------------------------------

run: ## Run Flutter web app (debug mode, auto-connects to emulators)
	flutter run -d chrome --web-port 3000

run-mobile: ## Run on connected mobile device
	flutter run

build: ## Build release web app
	flutter build web

# --- Quality -----------------------------------------------------------------

analyze: ## Run Flutter static analysis
	flutter analyze

test: ## Run Flutter tests
	flutter test

format: ## Format all Dart code
	dart format lib/ test/

check: analyze test ## Run all quality checks
	@echo "All checks passed."

# --- Cleanup -----------------------------------------------------------------

clean: stop ## Stop emulators and clean build artifacts
	@flutter clean
	@rm -rf emulator-data/
	@rm -f .emulator.log
	@echo "Clean complete."

# --- Help --------------------------------------------------------------------

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
