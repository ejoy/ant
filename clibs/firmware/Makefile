include ../common.mk

ifeq "$(PLAT)" "mingw"
default : firmware.dll
else
default : $(ODIR)/libfirmware.a
endif

FirmwareBootstrap.h: $(ANT)/engine/firmware/bootstrap.lua
	$(ANT)/bin/$(PLAT)/$(MODE)/lua $(ANT)/clibs/firmware/embed.lua $^ $@
FirmwareIo.h: $(ANT)/engine/firmware/io.lua
	$(ANT)/bin/$(PLAT)/$(MODE)/lua $(ANT)/clibs/firmware/embed.lua $^ $@
FirmwareVfs.h: $(ANT)/engine/firmware/vfs.lua
	$(ANT)/bin/$(PLAT)/$(MODE)/lua $(ANT)/clibs/firmware/embed.lua $^ $@

$(ODIR)/firmware.o : firmware.cpp FirmwareBootstrap.h FirmwareIo.h FirmwareVfs.h | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $< $(LUAINC)

$(ODIR)/firmware.dll : $(ODIR)/firmware.o
	$(CXX) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB)

$(ODIR)/libfirmware.a : $(ODIR)/firmware.o
	ar rsv $@ $^

firmware.dll : $(ODIR)/firmware.dll | $(ODIR)
	cp $^ $@

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a

