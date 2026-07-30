APP=MacBasic
BUILD=build
SOURCES=Sources/main.m Sources/MBCompiler.m Sources/MBInterpreter.m Sources/MBAppDelegate.m Sources/MBDocument.m
APP_BUNDLE=$(BUILD)/$(APP).app

ifeq ($(shell uname),Darwin)
  OBJCFLAGS=-fobjc-arc -fmodules -Wall -Wextra -Wno-unused-parameter
  LIBS=-framework Cocoa
  APP_EXECUTABLE=$(APP_BUNDLE)/Contents/MacOS/$(APP)
  COMPILED_APP_EXECUTABLE=$(BUILD)/CompiledLanguage.app/Contents/MacOS/CompiledLanguage
  COMPILED_APP_INFO=$(BUILD)/CompiledLanguage.app/Contents/Info.plist
  COMPILED_APP_ICON=$(BUILD)/CompiledLanguage.app/Contents/Resources/MacBasic.icns
else
  GCC_OBJC_INCLUDE=$(shell gcc -print-file-name=include)
  OBJCFLAGS=$(shell gnustep-config --objc-flags) -I$(GCC_OBJC_INCLUDE) -Wall -Wextra
  LIBS=$(shell gnustep-config --gui-libs)
  APP_EXECUTABLE=$(APP_BUNDLE)/$(APP)
  COMPILED_APP_EXECUTABLE=$(BUILD)/CompiledLanguage.app/CompiledLanguage
  COMPILED_APP_INFO=$(BUILD)/CompiledLanguage.app/Resources/Info-gnustep.plist
  COMPILED_APP_ICON=$(BUILD)/CompiledLanguage.app/Resources/MacBasicIcon.png
endif

.PHONY: all app clean test test-gnustep-docker
all: app

$(BUILD)/$(APP): $(SOURCES) Sources/MBCompiler.h Sources/MBInterpreter.h Sources/MBAppDelegate.h Sources/MBDocument.h
	mkdir -p $(BUILD)
	clang $(OBJCFLAGS) -o $@ $(SOURCES) $(LIBS)

app: $(BUILD)/$(APP)
ifeq ($(shell uname),Darwin)
	rm -rf $(BUILD)/$(APP).app
	mkdir -p $(BUILD)/$(APP).app/Contents/MacOS $(BUILD)/$(APP).app/Contents/Resources
	cp $(BUILD)/$(APP) $(BUILD)/$(APP).app/Contents/MacOS/
	cp Resources/Info.plist $(BUILD)/$(APP).app/Contents/
	cp Resources/MacBasic.icns Resources/MacBasicIcon.png Resources/MacBasicDocument.icns Resources/MacBasicDocumentIcon.png $(BUILD)/$(APP).app/Contents/Resources/
	cp Examples/Welcome.bas Examples/Drawing.bas $(BUILD)/$(APP).app/Contents/Resources/
else
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Resources
	cp $(BUILD)/$(APP) $(APP_EXECUTABLE)
	cp Resources/Info-gnustep.plist $(APP_BUNDLE)/Resources/
	cp Resources/MacBasicIcon.png Resources/MacBasicDocumentIcon.png $(APP_BUNDLE)/Resources/
	cp Examples/Welcome.bas Examples/Drawing.bas $(APP_BUNDLE)/Resources/
endif

test: $(BUILD)/$(APP)
	$(BUILD)/$(APP) Tests/language.bas | diff -u Tests/language.expected -
	$(BUILD)/$(APP) Tests/compatibility.bas | diff -u Tests/compatibility.expected -
	$(BUILD)/$(APP) --compile-tool Tests/language.bas $(BUILD)/language-compiled
	$(BUILD)/language-compiled --console | diff -u Tests/language.expected -
	$(BUILD)/$(APP) --compile-app Tests/language.bas $(BUILD)/CompiledLanguage.app
	test -x $(COMPILED_APP_EXECUTABLE)
	test -f $(COMPILED_APP_INFO)
	test -f $(COMPILED_APP_ICON)
	$(COMPILED_APP_EXECUTABLE) --console | diff -u Tests/language.expected -

test-gnustep-docker:
	docker build -f Tests/Dockerfile.gnustep -t macbasic-gnustep-check .
	docker run --rm -v "$(CURDIR):/src:ro" macbasic-gnustep-check

clean:
	rm -rf $(BUILD)
