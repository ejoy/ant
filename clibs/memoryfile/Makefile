include ../common.mk

mingw : memoryfile.dll

memoryfile.dll : memoryfile.c
	gcc --shared $(CFLAGS) -o $@ $^ $(LUALIB) $(LUAINC)

clean :
	rm -f memoryfile.dll
