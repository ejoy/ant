include ../common.mk

mingw : memoryfile.dll

memoryfile.o : memoryfile.c
	gcc -c $(CFLAGS) -o $@ $^ $(LUALIB) $(LUAINC)

memoryfile.dll : memoryfile.o
	gcc --shared $(CFLAGS) -o $@ $^ $(LUALIB) $(LUAINC)

libmemoryfile.a : memoryfile.o
	ar rsv $@ $^

clean :
	rm -f memoryfile.dll
