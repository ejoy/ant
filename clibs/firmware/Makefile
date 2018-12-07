include ../common.mk

ifeq "$(PLAT)" "mingw"
default : firmware.dll
else
default : libfirmware-$(PLAT).a
endif

$(ODIR)/firmware.o : firmware.cpp incbin.h \
	$(ANT3RD)/../runtime/core/firmware/bootstrap.lua \
	$(ANT3RD)/../runtime/core/firmware/io.lua \
	$(ANT3RD)/../runtime/core/firmware/vfs.lua | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $< $(LUAINC)

firmware.dll : $(ODIR)/firmware.o
	$(CC) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB)

libfirmware-$(PLAT).a : $(ODIR)/firmware.o
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a

