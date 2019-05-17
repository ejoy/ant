include ../common.mk
include ../bgfx/bgfx_define.mk

THREADINC=-I ../thread

ifeq "$(PLAT)" "mingw"
CFLAGS += -Wno-misleading-indentation -Wno-unused-but-set-variable
endif

ifeq "$(PLAT)" "mingw"
default : imgui.dll
else
default : libimgui-$(PLAT).a
endif

IMGUI_INC=$(BGFXSRC)/3rdparty/
IMGUI_SRC=$(BGFXSRC)/3rdparty/dear-imgui/
OBJS = $(ODIR)/luaimgui.o $(ODIR)/bgfximgui.o $(ODIR)/imgui.o $(ODIR)/imgui_draw.o $(ODIR)/imgui_widgets.o

$(ODIR)/luaimgui.o : luaimgui.cpp imgui/imgui.h | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $< $(LUAINC) $(BGFXINC) $(BGFX3RDINC) -I../bgfx -I../thread

$(ODIR)/bgfximgui.o : imgui/imgui.cpp  imgui/imgui.h $(IMGUI_SRC)../stb/stb_truetype.h | $(ODIR) 
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $< $(LUAINC) $(BGFXINC) $(BGFX3RDINC) -I../bgfx -I../thread


$(ODIR)/imgui.o : $(IMGUI_SRC)/imgui.cpp  | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $< -I$(IMGUI_INC) $(BGFXINC)

$(ODIR)/imgui_draw.o : $(IMGUI_SRC)/imgui_draw.cpp $(IMGUI_SRC)../stb/stb_truetype.h | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $< -I$(IMGUI_INC) $(BGFXINC)

$(ODIR)/imgui_widgets.o : $(IMGUI_SRC)/imgui_widgets.cpp  | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $< -I$(IMGUI_INC) $(BGFXINC)

imgui.dll : $(OBJS)
	$(CC) $(CFLAGS) $(LD_SHARED) -o $@ $^ $(LUALIB) -L$(BGFXLIBDIR) $(BXLIB) -lstdc++

libimgui-$(PLAT).a : $(OBJS)
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
