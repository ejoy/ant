ODIR = o
ANT3RD = ../../3rd

LUAINC = -I ../lua
LUALIB = -L ../lua -llua53
LUABIN = ../lua/lua.exe

AR= ar rcu
CC= gcc
CXX = g++
CFLAGS = -O2 -Wall
CXXFLAGS = -lstdc++ -std=c++17

BUILD_CONFIG = Release

