include ../common.mk

mingw : firmware.dll

firmware.o : firmware.cpp incbin.h
	g++ -c -std=c++17 $(CFLAGS) -o $@ $< $(LUAINC)

firmware.dll : firmware.o
	g++ --shared $(CFLAGS) -o $@ $^ $(LUALIB)

libfirmware.a : firmware.o
	ar rsv $@ $^

clean :
	rm -f firmware.dll *.o
