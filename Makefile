.PHONY: check doctor bootstrap build test-core test-ios verify handoff
.DEFAULT_GOAL := check
# Keep these steps ordered, including when make runs with -j.
verify:
	$(MAKE) check
	$(MAKE) test-core
	$(MAKE) build
	$(MAKE) test-ios
check:
	python3 scripts/check.py
doctor:
	./scripts/doctor.sh
bootstrap:
	./scripts/bootstrap.sh
build:
	./scripts/build-ios.sh
test-core:
	@if command -v swift >/dev/null 2>&1; then \
		swift test --package-path Packages/SlitCore; \
	else \
		echo 'Core tests need the Swift 6 toolchain. See docs/handoff/SETUP.md.' >&2; \
		echo 'On this host, run make doctor and make check.' >&2; \
		exit 2; \
	fi
test-ios:
	./scripts/test-ios.sh
handoff: check
	python3 scripts/package-handoff.py
