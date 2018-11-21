PLAT = mingw

ODIR = o
ANT3RD = ../../3rd

LUAINC = -I ../lua

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
LUALIB = -L ../lua -llua53
LUABIN = ../lua/lua.exe

else ifeq "$(PLAT)" "osx"

LUA_FLAGS = -DLUA_USE_MACOSX
LUALIB = -L ../lua -llua
LUABIN = ../lua/lua

endif
