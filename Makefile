.PHONY: check doctor bootstrap build test-core test-ios handoff
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
