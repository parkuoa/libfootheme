CC = clang
CFLAGS = -mmacosx-version-min=10.14 -framework QuartzCore -framework Foundation -framework AppKit -dynamiclib -fobjc-arc -O2
SOURCES = lib/libfootheme.m lib/uielem.m

FOOBAR_APP_PATH ?= /Applications/foobar2000.app
ARCH := $(shell uname -m)

ifeq ($(ARCH),arm64)
    ARCH_SUFFIX = -arch arm64
    TARGET = lib/libfootheme.dylib
else
    ARCH_SUFFIX = -arch x86_64
    TARGET = lib/libfootheme.dylib
endif

.PHONY: all clean run debug install
all: probe_fb2k_path $(TARGET)

probe_fb2k_path:
	@if [ ! -e "$(FOOBAR_APP_PATH)/Contents/MacOS/foobar2000" ]; then \
		if [ "$(origin FOOBAR_APP_PATH)" = "file" ]; then \
			echo "make: couldn't find '$(FOOBAR_APP_PATH)'. Try setting FOOBAR_APP_PATH"; \
		else \
			echo "make: path '$(FOOBAR_APP_PATH)' is invalid."; \
		fi; \
		exit 1; \
	fi

$(TARGET): $(SOURCES)
	$(CC) $(CFLAGS) $(ARCH_SUFFIX) -o $@ $^
	@echo "success: $(TARGET) ($(ARCH))"

clean:
	rm -f $(TARGET)

run: probe_fb2k_path $(TARGET)
	DYLD_INSERT_LIBRARIES=./$(TARGET) \
	DYLD_FORCE_FLAT_NAMESPACE=1 \
	"$(FOOBAR_APP_PATH)/Contents/MacOS/foobar2000"

debug: probe_fb2k_path $(TARGET)
	DYLD_INSERT_LIBRARIES=./$(TARGET) \
	DYLD_FORCE_FLAT_NAMESPACE=1 \
	DYLD_PRINT_LIBRARIES=1 \
	"$(FOOBAR_APP_PATH)/Contents/MacOS/foobar2000"

install: probe_fb2k_path $(TARGET)
	cp -f "$(FOOBAR_APP_PATH)/Contents/MacOS/foobar2000" $(FOOBAR_APP_PATH)/Contents/MacOS/fb2k.backup
	mkdir -p "$(FOOBAR_APP_PATH)/Contents/Frameworks"
	cp -f $(TARGET) "$(FOOBAR_APP_PATH)/Contents/Frameworks/libfootheme.dylib"

	install_name_tool -id "@rpath/libfootheme.dylib" "$(FOOBAR_APP_PATH)/Contents/Frameworks/libfootheme.dylib"

	/usr/libexec/PlistBuddy -c "Add :LSEnvironment dict" "$(FOOBAR_APP_PATH)/Contents/Info.plist" 2>/dev/null || true
	/usr/libexec/PlistBuddy -c "Add :LSEnvironment:DYLD_INSERT_LIBRARIES string \"@executable_path/../Frameworks/libfootheme.dylib\"" "$(FOOBAR_APP_PATH)/Contents/Info.plist" 2>/dev/null || \
	/usr/libexec/PlistBuddy -c "Set :LSEnvironment:DYLD_INSERT_LIBRARIES \"@executable_path/../Frameworks/libfootheme.dylib\"" "$(FOOBAR_APP_PATH)/Contents/Info.plist"

	codesign --force --deep --sign - "$(FOOBAR_APP_PATH)/Contents/Frameworks/libfootheme.dylib"
	codesign --force --deep --sign - "$(FOOBAR_APP_PATH)"

uninstall:
	/usr/libexec/PlistBuddy -c "Delete :LSEnvironment:DYLD_INSERT_LIBRARIES" "$(FOOBAR_APP_PATH)/Contents/Info.plist" 2>/dev/null || true
	/usr/libexec/PlistBuddy -c "Delete :LSEnvironment" "$(FOOBAR_APP_PATH)/Contents/Info.plist" 2>/dev/null || true
	rm -f "$(FOOBAR_APP_PATH)/Contents/Frameworks/libfootheme.dylib"
	mv -f "$(FOOBAR_APP_PATH)/Contents/MacOS/fb2k.backup" "$(FOOBAR_APP_PATH)/Contents/MacOS/foobar2000"
	codesign --force --deep --sign - "$(FOOBAR_APP_PATH)"