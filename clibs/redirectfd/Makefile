LUAINC = -I ../lua
LUALIB = -L ../lua -llua53
CFLAGS = -g -Wall

mingw : redirectfd.dll

redirectfd.dll : redirectfd.c
	gcc --shared $(CFLAGS) -o $@ $^ $(LUALIB) $(LUAINC) -lws2_32

clean :
	rm redirectfd.dll
