LUALIB = -I ../../clibs/lua
LUAINC = -L ../../clibs/lua -llua

testluavm.exe : testluavm.c luavm.c
	gcc -Wall -g -o $@ $^ $(LUAINC) $(LUALIB)

clean :
	rm testluavm.exe
