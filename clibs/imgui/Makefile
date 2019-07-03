include ../common.mk
include ../bgfx/bgfx_define.mk

ifeq "$(PLAT)" "mingw"
default : $(ODIR)/imgui.dll
else
default : $(ODIR)/libimgui.a
endif

IMGUI_INC=-I$(ANT3RD)/imgui
IMGUI_SRC=$(ANT3RD)/imgui
IMGUI_MACRO=-DIMGUI_DISABLE_OBSOLETE_FUNCTIONS

OBJS = $(ODIR)/luaimgui.o $(ODIR)/imgui.o $(ODIR)/imgui_draw.o $(ODIR)/imgui_widgets.o

ifeq "$(PLAT)" "mingw"
CFLAGS += -Wno-misleading-indentation -Wno-unused-but-set-variable
OBJS += $(ODIR)/imgui_win32.o

$(ODIR)/imgui_win32.o : imgui_win32.cpp | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $< $(IMGUI_INC) $(IMGUI_MACRO)
endif

ifeq "$(PLAT)" "osx"
OBJS += $(ODIR)/imgui_osx.o

$(ODIR)/imgui_osx.o : imgui_osx.mm | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $< $(IMGUI_INC) $(IMGUI_MACRO)
endif

ifeq "$(PLAT)" "ios"
OBJS += $(ODIR)/imgui_ios.o

$(ODIR)/imgui_ios.o : imgui_ios.mm | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $< $(IMGUI_INC) $(IMGUI_MACRO)
endif

$(ODIR)/luaimgui.o : luaimgui.cpp | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $< $(LUAINC) $(IMGUI_INC) $(IMGUI_MACRO) $(BGFXINC) -I../bgfx -I$(ANT3RD)/glm


$(ODIR)/imgui.o : $(IMGUI_SRC)/imgui.cpp  $(IMGUI_SRC)/imgui_internal.h | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $< $(IMGUI_INC) $(IMGUI_MACRO)

$(ODIR)/imgui_draw.o : $(IMGUI_SRC)/imgui_draw.cpp $(IMGUI_SRC)/imstb_truetype.h $(IMGUI_SRC)/imgui_internal.h | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $< $(IMGUI_INC) $(IMGUI_MACRO)

$(ODIR)/imgui_widgets.o : $(IMGUI_SRC)/imgui_widgets.cpp $(IMGUI_SRC)/imgui_internal.h | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $< $(IMGUI_INC) $(IMGUI_MACRO)

$(ODIR)/imgui.dll : $(OBJS)
	$(CC) $(CFLAGS) $(LD_SHARED) -o $@ $^ $(LUALIB) -lstdc++ -limm32

$(ODIR)/libimgui.a : $(OBJS)
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
