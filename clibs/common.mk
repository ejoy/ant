ifeq "$(PLAT)" ""
PLAT = mingw
endif

ODIR = o
ANT3RD = ../../3rd

LUAINC = -I../lua

AR= ar rcu
CC= gcc

BUILD_CONFIG = Release

CXX = g++
ifeq ("$(BUILD_CONFIG)","Release")
DEBUG_INFO = -O2
else
DEBUG_INFO = -g
endif

CFLAGS = $(DEBUG_INFO) -Wall
CXXFLAGS = -lstdc++ -std=c++17

ifeq "$(PLAT)" "mingw"

LUA_FLAGS = -DLUA_BUILD_AS_DLL
LUALIB = -L../lua -llua53
LUABIN = ../lua/lua.exe

else ifeq "$(PLAT)" "osx"

LUA_FLAGS = -DLUA_USE_MACOSX
LUALIB = -L../lua
LUABIN = ../lua/lua

endif

ifeq "$(PLAT)" "osx"
LD_SHARED = -fPIC -dynamiclib -Wl,-undefined,dynamic_lookup
STRIP = strip -u -r -x
else
LD_SHARED = --shared
STRIP = strip --strip-unneeded
endif
