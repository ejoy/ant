LUALIB = -I ../../clibs/lua
LUAINC = -L ../../clibs/lua -llua
LFS = ../../clibs/winfile/winfile.c

all : testluavm.exe testvfs.exe

testluavm.exe : testluavm.c luavm.c
	gcc -Wall -g -o $@ $^ $(LUAINC) $(LUALIB)

testvfs.exe : testvfs.c luavm.c vfs.c $(LFS)
	gcc -Wall -g -o $@ $^ $(LUAINC) $(LUALIB)

clean :
	rm testluavm.exe testvfs.exe
