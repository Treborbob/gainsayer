.PHONY: build app run install clean

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

clean:
	rm -rf .build build
