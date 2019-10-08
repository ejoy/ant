ifeq "$(PLAT)" ""
	ifeq ($(shell uname), Darwin)
		PLAT = osx
	else
		PLAT = mingw
	endif
endif

OROOT = o
ODIR = $(OROOT)/$(PLAT)/$(MODE)
ANT3RD = ../../3rd
ANTCLIBS = ../../clibs

LUAINC = -I../lua

CC= gcc -std=c11
CXX = g++ -std=c++17

MODE = release

ifeq ("$(MODE)","release")
DEBUG_INFO = -O2
else
DEBUG_INFO = -g
endif

ifeq "$(PLAT)" "mingw"

LUA_FLAGS = -DLUA_BUILD_AS_DLL
LUALIB = -L../lua/$(ODIR) -llua53
LUABIN = ../lua/lua.exe
LD_SHARED = --shared
ifeq ("$(MODE)","release")
STRIP = strip --strip-unneeded
else
STRIP = echo
endif
CFLAGS = $(DEBUG_INFO) -Wall

else ifeq "$(PLAT)" "osx"

LUA_FLAGS = -DLUA_USE_MACOSX
LUALIB = -L../lua
LUABIN = ../lua/lua
LD_SHARED = -fPIC -dynamiclib -Wl,-undefined,dynamic_lookup
ifeq ("$(MODE)","release")
STRIP = strip -u -r -x
else
STRIP = echo
endif
CFLAGS = $(DEBUG_INFO) -Wall -mmacosx-version-min=10.15

else ifeq "$(PLAT)" "ios"

LUA_FLAGS =
LUALIB = -L../lua
LUABIN = ../lua/lua
LD_SHARED = -fPIC -dynamiclib -Wl,-undefined,dynamic_lookup
STRIP = echo # -u -r -x
CFLAGS= $(DEBUG_INFO) -Wall -arch arm64 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk -miphoneos-version-min=11.0 -fembed-bitcode -fobjc-arc

endif
