include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = MacBasic
GCC_OBJC_INCLUDE = $(shell gcc -print-file-name=include)
MACBASIC_RUNTIME_OBJCFLAGS = $(shell gnustep-config --objc-flags) -I$(GCC_OBJC_INCLUDE) -Wall -Wextra
MACBASIC_RUNTIME_LIBRARY = build/libMacBasicRuntime.a

MacBasic_OBJC_FILES = \
	Sources/main.m \
	Sources/MBCompiler.m \
	Sources/MBInterpreter.m \
	Sources/MBAppDelegate.m \
	Sources/MBDocument.m

MacBasic_RESOURCE_FILES = \
	$(MACBASIC_RUNTIME_LIBRARY) \
	Sources/MBInterpreter.h \
	Resources/MacBasicIcon.png \
	Resources/MacBasicDocumentIcon.png \
	Examples/Welcome.bas \
	Examples/Drawing.bas \
	Examples/Paraboloid3D.bas \
	Examples/Advanced.bas

MacBasic_PRINCIPAL_CLASS = NSApplication
MacBasic_APPLICATION_ICON = MacBasicIcon.png
MacBasic_OBJCFLAGS = -Wall -Wextra -Wno-unused-parameter
MacBasic_OBJC_LIBS = -lsqlite3

include $(GNUSTEP_MAKEFILES)/application.make

.PHONY: check test

before-all:: $(MACBASIC_RUNTIME_LIBRARY)

before-clean::
	rm -rf build

build/MBInterpreter.o: Sources/MBInterpreter.m Sources/MBInterpreter.h
	mkdir -p build
	clang $(MACBASIC_RUNTIME_OBJCFLAGS) -c -o $@ $<

build/MBDocument.o: Sources/MBDocument.m Sources/MBDocument.h Sources/MBInterpreter.h Sources/MBCompiler.h
	mkdir -p build
	clang $(MACBASIC_RUNTIME_OBJCFLAGS) -c -o $@ $<

$(MACBASIC_RUNTIME_LIBRARY): build/MBInterpreter.o build/MBDocument.o
	ar rcs $@ $^

check:: all
	./MacBasic.app/MacBasic Tests/language.bas | diff -u Tests/language.expected -
	./MacBasic.app/MacBasic Tests/compatibility.bas | diff -u Tests/compatibility.expected -

test:: all
	./MacBasic.app/MacBasic Tests/language.bas | diff -u Tests/language.expected -
	./MacBasic.app/MacBasic Tests/compatibility.bas | diff -u Tests/compatibility.expected -
