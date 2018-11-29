include ../common.mk

mingw : firmware.dll

firmware.cpp : |

firmware.o : firmware.cpp incbin.h \
	$(ANT3RD)/../runtime/core/firmware/bootstrap.lua \
	$(ANT3RD)/../runtime/core/firmware/io.lua \
	$(ANT3RD)/../runtime/core/firmware/vfs.lua
	g++ -c -std=c++17 $(CFLAGS) -o $@ $< $(LUAINC)

firmware.dll : firmware.o
	g++ $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB)

libfirmware.a : firmware.o
	ar rsv $@ $^

clean :
	rm -f firmware.dll *.o
