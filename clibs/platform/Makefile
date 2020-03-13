include ../common.mk
include ../bgfx/bgfx_define.mk

ifeq "$(PLAT)" "mingw"
default : platform.dll
else
default : $(ODIR)/libplatform.a
endif

ifeq "$(PLAT)" "mingw"
PLAT_LIB = -lgdi32 -lstdc++ -lole32 -loleaut32 -lwbemuuid
PLAT_CXX = cpp
else ifeq "$(PLAT)" "osx"
PLAT_LIB = -framework AppKit
PLAT_CXX = mm
else ifeq "$(PLAT)" "ios"
PLAT_LIB =
PLAT_CXX = mm
endif

OBJS = $(ODIR)/lplatform.o $(ODIR)/platform_$(PLAT).o $(ODIR)/platform_timer.o

ifeq "$(PLAT)" "mingw"
$(ODIR)/win32_wmi.o : win32/wmi.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<
OBJS += $(ODIR)/win32_wmi.o
else
$(ODIR)/osx_task_info.o : osx/task_info.mm | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<
$(ODIR)/osx_font_info.o : osx/font_info.mm | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<
OBJS += $(ODIR)/osx_task_info.o $(ODIR)/osx_font_info.o
endif

$(ODIR)/platform_timer.o : platform_timer.cpp | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $^ $(LUAINC) -I$(BXSRC)/include

$(ODIR)/platform_$(PLAT).o : platform_$(PLAT).$(PLAT_CXX) | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

$(ODIR)/lplatform.o : lplatform.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -I$(BXSRC)/include -o $@ $<

$(ODIR)/platform.dll : $(OBJS)
	$(CC) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB) $(PLAT_LIB)

$(ODIR)/libplatform.a : $(OBJS)
	ar rsv $@ $^

platform.dll : $(ODIR)/platform.dll | $(ODIR)
	cp $^ $@

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
