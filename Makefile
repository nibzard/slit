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
	swift test --package-path Packages/SlitCore
test-ios:
	./scripts/test-ios.sh
handoff: check
	python3 scripts/package-handoff.py
