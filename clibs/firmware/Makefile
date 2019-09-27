include ../common.mk

ifeq "$(PLAT)" "mingw"
default : firmware.dll
else
default : $(ODIR)/libfirmware.a
endif

LUAEXE = cd ../.. && ./clibs/lua.exe
ifeq "$(PLAT)" "mingw"
IDENTITY = .windows_direct3d11
endif
ifeq "$(PLAT)" "osx"
IDENTITY = .osx_metal
endif
ifeq "$(PLAT)" "ios"
IDENTITY = .ios_metal
endif

define COMPILE_SHADER
$(ODIR)/$(1) : $(ANT3RD)/../packages/imguibase/shader/$(1)
	$(LUAEXE) tools/shaderc/main.lua $(IDENTITY) packages/imguibase/shader/$(1) clibs/firmware/$(ODIR)/$(1)
endef

SHADERS = fs_imgui_image.sc fs_imgui_font.sc vs_imgui_image.sc vs_imgui_font.sc
$(foreach v, $(SHADERS), $(eval $(call COMPILE_SHADER,$(v))))

$(ODIR)/firmware.o : firmware.cpp incbin.h \
	$(ANT3RD)/../engine/firmware/bootstrap.lua \
	$(ANT3RD)/../engine/firmware/io.lua \
	$(ANT3RD)/../engine/firmware/vfs.lua \
	$(ODIR)/fs_imgui_image.sc \
	$(ODIR)/fs_imgui_font.sc \
	$(ODIR)/vs_imgui_image.sc \
	$(ODIR)/vs_imgui_font.sc \
	| $(ODIR)
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

