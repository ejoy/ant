ODIR = o
ANT3RD = ../../3rd

LUAINC = -I ../lua
LUALIB = -L ../lua -llua53
LUABIN = ../lua/lua.exe

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
