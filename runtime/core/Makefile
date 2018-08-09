LUALIB = -I ../../clibs/lua
LUAINC = -L ../../clibs/lua -llua

all : testluavm.exe testvfs.exe

testluavm.exe : testluavm.c luavm.c
	gcc -Wall -g -o $@ $^ $(LUAINC) $(LUALIB)

testvfs.exe : testvfs.c luavm.c vfs.c
	gcc -Wall -g -o $@ $^ $(LUAINC) $(LUALIB)

clean :
	rm testluavm.exe testvfs.exe
