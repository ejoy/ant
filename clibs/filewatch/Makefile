LUAINC = -I../lua
LUALIB = -L../lua -llua53
CFLAGS = -O2 -Wall

mingw : filewatch.dll

filewatch.cpp : filewatch.h queue.h

luafilewatch.cpp : filewatch.h

filewatch.dll : filewatch.cpp luafilewatch.cpp
	g++ --shared $(CFLAGS) $(LUAINC) -o $@ $^ $(LUALIB)

clean :
	rm -f filewatch.dll
