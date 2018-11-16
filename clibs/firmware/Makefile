include ../common.mk

mingw : firmware.dll

firmware.o : firmware.c
	gcc -c $(CFLAGS) -o $@ $^ $(LUALIB) $(LUAINC)

firmware.dll : firmware.o
	gcc --shared $(CFLAGS) -o $@ $^ $(LUALIB) $(LUAINC)

libfirmware.a : firmware.o
	ar rsv $@ $^

clean :
	rm -f firmware.dll *.o
