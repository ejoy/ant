include ../common.mk

ifeq "$(PLAT)" "mingw"
default : firmware.dll
else
default : libfirmware.a
endif

firmware.o : firmware.cpp incbin.h \
	$(ANT3RD)/../runtime/core/firmware/bootstrap.lua \
	$(ANT3RD)/../runtime/core/firmware/io.lua \
	$(ANT3RD)/../runtime/core/firmware/vfs.lua
	$(CXX) -c $(CFLAGS) -o $@ $< $(LUAINC)

firmware.dll : firmware.o
	$(CC) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB)

libfirmware.a : firmware.o
	ar rsv $@ $^

clean :
	rm -f firmware.dll libfirmware.a *.o
