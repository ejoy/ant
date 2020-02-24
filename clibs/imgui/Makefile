include ../common.mk
include ../bgfx/bgfx_define.mk

ifeq "$(PLAT)" "mingw"
default : imgui.dll
else
default : $(ODIR)/libimgui.a
endif

IMGUI_INC=-I$(ANT3RD)/imgui
IMGUI_SRC=$(ANT3RD)/imgui
IMGUI_MACRO  = -DIMGUI_DISABLE_OBSOLETE_FUNCTIONS
IMGUI_MACRO += -DIMGUI_DISABLE_METRICS_WINDOW
IMGUI_MACRO += -DIMGUI_DISABLE_DEMO_WINDOWS
IMGUI_MACRO += -DIMGUI_DISABLE_DEFAULT_ALLOCATORS
IMGUI_MACRO += -I. -DIMGUI_USER_CONFIG=\"imgui_config.h\"

WINDOW_INC=-I$(ANTCLIBS)/window

OBJS = $(ODIR)/luaimgui.o $(ODIR)/imgui_ant.o $(ODIR)/imgui_config.o $(ODIR)/imgui.o $(ODIR)/imgui_draw.o $(ODIR)/imgui_widgets.o

ifeq "$(PLAT)" "mingw"
CFLAGS += -Wno-misleading-indentation -Wno-unused-but-set-variable
OBJS += $(ODIR)/imgui_win32.o
LIBS = -limm32

$(ODIR)/imgui_win32.o : imgui_win32.cpp | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $< $(IMGUI_INC) $(WINDOW_INC) $(IMGUI_MACRO)
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

$(ODIR)/imgui_ant.o : imgui_ant.cpp | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $< $(LUAINC) $(IMGUI_INC) $(IMGUI_MACRO) $(BGFXINC) -I../bgfx -I$(ANT3RD)/glm

$(ODIR)/imgui_config.o : imgui_config.cpp $(IMGUI_SRC)/imgui.h | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $< $(LUAINC) $(IMGUI_INC) $(IMGUI_MACRO)

$(ODIR)/imgui.o : $(IMGUI_SRC)/imgui.cpp  $(IMGUI_SRC)/imgui_internal.h | $(ODIR)
	$(CXX) $(CFLAGS) -c -o $@ $< $(IMGUI_INC) $(IMGUI_MACRO)

$(ODIR)/imgui_draw.o : $(IMGUI_SRC)/imgui_draw.cpp $(IMGUI_SRC)/imstb_truetype.h $(IMGUI_SRC)/imgui_internal.h | $(ODIR)
	$(CXX) $(CFLAGS) -c -o $@ $< $(IMGUI_INC) $(IMGUI_MACRO)

$(ODIR)/imgui_widgets.o : $(IMGUI_SRC)/imgui_widgets.cpp $(IMGUI_SRC)/imgui_internal.h | $(ODIR)
	$(CXX) $(CFLAGS) -c -o $@ $< $(IMGUI_INC) $(IMGUI_MACRO)

$(ODIR)/imgui.dll : $(OBJS)
	$(CC) $(CFLAGS) $(LD_SHARED) -o $@ $^ $(LUALIB) -lstdc++ $(LIBS)

imgui.dll: $(ODIR)/imgui.dll | $(ODIR)
	cp $^ $@

$(ODIR)/libimgui.a : $(OBJS)
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
