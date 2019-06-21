include ../common.mk

ifeq "$(PLAT)" "mingw"
default : firmware.dll
else
default : $(ODIR)/libfirmware.a
endif

$(ODIR)/firmware.o : firmware.cpp incbin.h \
	$(ANT3RD)/../engine/firmware/bootstrap.lua \
	$(ANT3RD)/../engine/firmware/io.lua \
	$(ANT3RD)/../engine/firmware/vfs.lua | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $< $(LUAINC)

$(ODIR)/firmware.dll : $(ODIR)/firmware.o
	$(CC) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB)

$(ODIR)/libfirmware.a : $(ODIR)/firmware.o
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a

