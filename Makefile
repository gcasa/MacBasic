APP=MacBasic
BUILD=build
SOURCES=Sources/main.m Sources/MBInterpreter.m Sources/MBAppDelegate.m Sources/MBDocument.m

ifeq ($(shell uname),Darwin)
  OBJCFLAGS=-fobjc-arc -fmodules -Wall -Wextra -Wno-unused-parameter
  LIBS=-framework Cocoa
else
  OBJCFLAGS=$(shell gnustep-config --objc-flags) -Wall -Wextra
  LIBS=$(shell gnustep-config --gui-libs)
endif

.PHONY: all app clean test
all: $(BUILD)/$(APP)

$(BUILD)/$(APP): $(SOURCES) Sources/MBInterpreter.h Sources/MBAppDelegate.h Sources/MBDocument.h
	mkdir -p $(BUILD)
	clang $(OBJCFLAGS) -o $@ $(SOURCES) $(LIBS)

app: $(BUILD)/$(APP)
	rm -rf $(BUILD)/$(APP).app
	mkdir -p $(BUILD)/$(APP).app/Contents/MacOS $(BUILD)/$(APP).app/Contents/Resources
	cp $(BUILD)/$(APP) $(BUILD)/$(APP).app/Contents/MacOS/
	cp Resources/Info.plist $(BUILD)/$(APP).app/Contents/
	cp Resources/MacBasic.icns Resources/MacBasicIcon.png $(BUILD)/$(APP).app/Contents/Resources/
	cp Examples/Welcome.bas Examples/Drawing.bas $(BUILD)/$(APP).app/Contents/Resources/

test: $(BUILD)/$(APP)
	$(BUILD)/$(APP) Tests/language.bas | diff -u Tests/language.expected -
	$(BUILD)/$(APP) Tests/compatibility.bas | diff -u Tests/compatibility.expected -

clean:
	rm -rf $(BUILD)
