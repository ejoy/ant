LUAINC = -I ../lua
LUALIB = -L ../lua -llua53
CFLAGS = -O2 -Wall

mingw : memoryfile.dll

memoryfile.dll : memoryfile.c
	gcc --shared $(CFLAGS) -o $@ $^ $(LUALIB) $(LUAINC)

clean :
	rm -f memoryfile.dll
