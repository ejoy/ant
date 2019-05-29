include ../common.mk
include ../bgfx/bgfx_define.mk

ifeq "$(PLAT)" "mingw"
default : imgui.dll
else
default : libimgui-$(PLAT).a
endif

IMGUI_INC=-I$(ANT3RD)/imgui
IMGUI_SRC=$(ANT3RD)/imgui

OBJS = $(ODIR)/luaimgui.o $(ODIR)/imgui.o $(ODIR)/imgui_draw.o $(ODIR)/imgui_widgets.o

ifeq "$(PLAT)" "mingw"
CFLAGS += -Wno-misleading-indentation -Wno-unused-but-set-variable
OBJS += $(ODIR)/imgui_win32.o

$(ODIR)/imgui_win32.o : imgui_win32.cpp | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $< $(IMGUI_INC)
endif

ifeq "$(PLAT)" "osx"
OBJS += $(ODIR)/imgui_osx.o

$(ODIR)/imgui_osx.o : imgui_osx.mm | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $< $(IMGUI_INC)
endif


$(ODIR)/luaimgui.o : luaimgui.cpp | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $< $(LUAINC) $(IMGUI_INC) $(BGFXINC) -I../bgfx -I$(ANT3RD)/glm


$(ODIR)/imgui.o : $(IMGUI_SRC)/imgui.cpp  $(IMGUI_SRC)/imgui_internal.h | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $< $(IMGUI_INC)

$(ODIR)/imgui_draw.o : $(IMGUI_SRC)/imgui_draw.cpp $(IMGUI_SRC)/imstb_truetype.h $(IMGUI_SRC)/imgui_internal.h | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $< $(IMGUI_INC)

$(ODIR)/imgui_widgets.o : $(IMGUI_SRC)/imgui_widgets.cpp $(IMGUI_SRC)/imgui_internal.h | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $< $(IMGUI_INC)

imgui.dll : $(OBJS)
	$(CC) $(CFLAGS) $(LD_SHARED) -o $@ $^ $(LUALIB) -lstdc++ -limm32

libimgui-$(PLAT).a : $(OBJS)
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
