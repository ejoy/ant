ODIR = o
ANT3RD = ../../../ant3rd
IUPSRC = $(ANT3RD)/iup
LUAINC = -I ../lua
LUALIB = -L ../lua -llua53
LUABIN = ../lua/lua.exe

AR= ar rcu
CC= gcc
CXX = g++
CFLAGS = -O2 -Wall
