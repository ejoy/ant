ifeq "$(PLAT)" ""
	ifeq ($(shell uname), Darwin)
		PLAT = osx
	else
		PLAT = mingw
	endif
endif

OROOT = o
ODIR := $(OROOT)/$(PLAT)
ANT3RD = ../../3rd

LUAINC = -I../lua

CC= gcc -std=c11
CXX = g++ -std=c++17

BUILD_CONFIG = Release

ifeq ("$(BUILD_CONFIG)","Release")
DEBUG_INFO = -O2
else
DEBUG_INFO = -g
endif

ifeq "$(PLAT)" "mingw"

LUA_FLAGS = -DLUA_BUILD_AS_DLL
LUALIB = -L../lua -llua53
LUABIN = ../lua/lua.exe
LD_SHARED = --shared
STRIP = strip --strip-unneeded
CFLAGS = $(DEBUG_INFO) -Wall

else ifeq "$(PLAT)" "osx"

LUA_FLAGS = -DLUA_USE_MACOSX
LUALIB = -L../lua
LUABIN = ../lua/lua
LD_SHARED = -fPIC -dynamiclib -Wl,-undefined,dynamic_lookup
STRIP = strip -u -r -x
CFLAGS = $(DEBUG_INFO) -Wall

else ifeq "$(PLAT)" "ios"

LUA_FLAGS =
LUALIB = -L../lua
LUABIN = ../lua/lua
LD_SHARED = -fPIC -dynamiclib -Wl,-undefined,dynamic_lookup
STRIP = echo # -u -r -x
CFLAGS= $(DEBUG_INFO) -Wall -arch arm64 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk -miphoneos-version-min=10.0 -fembed-bitcode

endif
