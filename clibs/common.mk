ifeq "$(PLAT)" ""
	ifeq ($(shell uname), Darwin)
		PLAT = osx
	else
		PLAT = mingw
	endif
endif

OROOT = o
ODIR = $(OROOT)/$(PLAT)/$(MODE)
ANT = ../..
ANT3RD = $(ANT)/3rd
ANTCLIBS = $(ANT)/clibs

CLIBSINC = -I$(ANTCLIBS)

LUAINC = -I$(ANT)/clibs/lua

CC= gcc -std=c11
CXX = g++ -std=c++2a

MODE = release

ifeq ("$(MODE)","release")
DEBUG_INFO = -O2
else
DEBUG_INFO = -g
endif

ifeq "$(PLAT)" "mingw"

LUA_FLAGS = -DLUA_BUILD_AS_DLL
LUALIB = -L$(ANT)/clibs/lua/$(ODIR) -llua54
LUABIN = $(ANT)/clibs/lua/lua.exe
LD_SHARED = --shared
ifeq ("$(MODE)","release")
STRIP = strip --strip-unneeded
else
STRIP = echo
endif
CFLAGS = $(DEBUG_INFO) -Wall

else ifeq "$(PLAT)" "osx"

LUA_FLAGS = -DLUA_USE_MACOSX
LUALIB = -L$(ANT)/clibs/lua
LUABIN = $(ANT)/clibs/lua/lua
LD_SHARED = -fPIC -dynamiclib -Wl,-undefined,dynamic_lookup
ifeq ("$(MODE)","release")
STRIP = strip -u -r -x
else
STRIP = echo
endif
CFLAGS = $(DEBUG_INFO) -Wall -mmacosx-version-min=10.15

else ifeq "$(PLAT)" "ios"

LUA_FLAGS =
LUALIB = -L$(ANT)/clibs/lua
LUABIN = $(ANT)/clibs/lua/lua
LD_SHARED = -fPIC -dynamiclib -Wl,-undefined,dynamic_lookup
STRIP = echo # -u -r -x
CFLAGS= $(DEBUG_INFO) -Wall -arch arm64 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk -miphoneos-version-min=13.0 -fembed-bitcode -fobjc-arc

endif
