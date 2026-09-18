.PHONY: build app run install clean check lint format test icon

build:
	swift build

app:
	scripts/build-app.sh

run: app
	pkill -x Gainsayer || true
	open build/Gainsayer.app

install: app
	pkill -x Gainsayer || true
	rm -rf /Applications/Gainsayer.app
	cp -R build/Gainsayer.app /Applications/
	open /Applications/Gainsayer.app

check: lint test

lint:
	swift format lint --strict --recursive Sources Tests Package.swift

format:
	swift format format --in-place --recursive Sources Tests Package.swift

test:
	swift test

icon:
	swift scripts/make-icon.swift

clean:
	rm -rf .build build
