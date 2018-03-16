LUAINC = -I ../lua
LUALIB = -L ../lua -llua53
CFLAGS = -O2 -Wall

mingw : lanes.dll

lanes.dll : lanes.c compat.c threading.c tools.c deep.c keeper.c universe.c
	gcc --shared $(CFLAGS) -o $@ $^ $(LUALIB) $(LUAINC)

clean :
	rm -f lanes.dll
