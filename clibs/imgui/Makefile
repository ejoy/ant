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

IMNODES_DIR=$(ANT3RD)/imnodes
IMNODES_SRC=$(IMNODES_DIR)
IMNODES_INC=-I$(IMNODES_DIR)

WINDOW_INC=-I$(ANTCLIBS)/window

OBJS = $(ODIR)/luaimgui.o $(ODIR)/imgui_window.o $(ODIR)/imgui_renderer.o $(ODIR)/imgui_platform.o $(ODIR)/imgui_config.o $(ODIR)/imgui.o $(ODIR)/imgui_widgets.o $(ODIR)/imgui_draw.o

ifeq "$(PLAT)" "mingw"
OBJS += $(ODIR)/imgui_impl_win32.o
LIBS = -limm32 -lgdi32 -lxinput
IMGUI_MACRO += -DUNICODE -D_UNICODE
IMGUI_PLAT = win32
endif

ifeq "$(PLAT)" "osx"
IMGUI_PLAT = osx
endif

$(ODIR)/imgui_window.o : imgui_window.cpp | $(ODIR)
	$(CXX) $(CFLAGS) -c -o $@ $< $(LUAINC) $(IMGUI_INC) $(WINDOW_INC) $(IMGUI_MACRO)

$(ODIR)/luaimgui.o : luaimgui.cpp | $(ODIR)
	$(CXX) $(CFLAGS) -c -o $@ $< $(LUAINC) $(IMGUI_INC) $(IMGUI_MACRO) $(BGFXINC) -I../bgfx -I$(ANT3RD)/glm

$(ODIR)/imgui_renderer.o : imgui_renderer.cpp imgui_renderer.h | $(ODIR)
	$(CXX) $(CFLAGS) -c -o $@ $< $(LUAINC) $(IMGUI_INC) $(IMGUI_MACRO) $(BGFXINC) -I../bgfx -I$(ANT3RD)/glm

$(ODIR)/imgui_platform.o : $(IMGUI_PLAT)/imgui_platform.cpp imgui_platform.h | $(ODIR)
	$(CXX) $(CFLAGS) -c -o $@ $< $(LUAINC) $(IMGUI_INC) $(IMGUI_MACRO) $(BGFXINC)

$(ODIR)/imgui_config.o : imgui_config.cpp $(IMGUI_SRC)/imgui.h | $(ODIR)
	$(CXX) $(CFLAGS) -c -o $@ $< $(LUAINC) $(IMGUI_INC) $(IMGUI_MACRO) $(BGFXINC) -I../bgfx

$(ODIR)/imgui.o : $(IMGUI_SRC)/imgui.cpp  $(IMGUI_SRC)/imgui_internal.h | $(ODIR)
	$(CXX) $(CFLAGS) -c -o $@ $< $(IMGUI_INC) $(IMGUI_MACRO)

$(ODIR)/imgui_draw.o : $(IMGUI_SRC)/imgui_draw.cpp $(IMGUI_SRC)/imstb_truetype.h $(IMGUI_SRC)/imgui_internal.h | $(ODIR)
	$(CXX) $(CFLAGS) -c -o $@ $< $(IMGUI_INC) $(IMGUI_MACRO)

$(ODIR)/imgui_widgets.o : $(IMGUI_SRC)/imgui_widgets.cpp $(IMGUI_SRC)/imgui_internal.h | $(ODIR)
	$(CXX) $(CFLAGS) -c -o $@ $< $(IMGUI_INC) $(IMGUI_MACRO)

$(ODIR)/imgui_impl_win32.o : $(IMGUI_SRC)/examples/imgui_impl_win32.cpp | $(ODIR)
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
