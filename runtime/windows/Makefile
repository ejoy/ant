LUAINC = -I ../../clibs/lua
LUALIB = -L ../../clibs/lua -llua53
CFLAGS = -Wall -g

LUAVM = ../core
LUAVMINC = -I $(LUAVM)

.PHONY : all clean mingw

all : antclient.exe

mingw : all

antclient.exe : winfile.c winmain.c config.c $(LUAVM)/luavm.c
	gcc $(CFLAGS) -o $@ $^ $(LUAINC) $(LUAVMINC) $(LUALIB)

test.exe : test.c winfile.c
	gcc $(CFLAGS) -o $@ $^

clean :
	rm -f test.exe antclient.exe
