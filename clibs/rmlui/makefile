include ../common.mk
include ../bgfx/bgfx_define.mk

ifeq "$(PLAT)" "mingw"
default : rmlui.dll
else
default : $(ODIR)/librmlui.a
endif

rmlui.dll : $(ODIR)/rmlui.dll
	cp $< $@

RMLUIINC=-I$(ANT3RD)/RmlUi/Include

$(ODIR)/file.o : file.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ -DRMLUI_STATIC_LIB $(LUAINC) $(RMLUIINC) $(BGFXINC)

$(ODIR)/font.o : font.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ -DRMLUI_STATIC_LIB $(LUAINC) $(CLIBSINC) $(BGFX3RDINC) $(BGFXINC) $(RMLUIINC)

$(ODIR)/render.o : render.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ -DRMLUI_STATIC_LIB $(LUAINC) $(CLIBSINC) $(BGFX3RDINC) $(BGFXINC) $(RMLUIINC)

$(ODIR)/system.o : system.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ -DRMLUI_STATIC_LIB $(LUAINC) $(CLIBSINC) $(BGFX3RDINC) $(BGFXINC) $(RMLUIINC)

$(ODIR)/context.o : context.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ -DRMLUI_STATIC_LIB $(LUAINC) $(CLIBSINC) $(BGFX3RDINC) $(BGFXINC) $(RMLUIINC)

$(ODIR)/fonteffect.o : fonteffect.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ -DRMLUI_STATIC_LIB $(LUAINC) $(CLIBSINC) $(BGFX3RDINC) $(BGFXINC) $(RMLUIINC)

$(ODIR)/luarmlui.o : luarmlui.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ -DRMLUI_STATIC_LIB $(LUAINC) $(CLIBSINC) $(BGFX3RDINC) $(BGFXINC) $(RMLUIINC)


RMLLUA_DIR = $(ANT3RD)/RmlUi/Source
RMLLUA = $(patsubst $(RMLLUA_DIR)/%.cpp,%,$(wildcard $(RMLLUA_DIR)/Lua/*.cpp)) $(patsubst $(RMLLUA_DIR)/%.cpp,%,$(wildcard $(RMLLUA_DIR)/Lua/Elements/*.cpp))

define RMLLUA_COMPLILE
$(ODIR)/$(1).o : $(RMLLUA_DIR)/$(1).cpp | $(ODIR)/Lua/Elements
	$(CXX) -c $(CFLAGS) -o $$@ $$^ -DRMLUI_STATIC_LIB $(LUAINC) $(CLIBSINC) $(RMLUIINC)
endef
$(foreach v, $(RMLLUA), $(eval $(call RMLLUA_COMPLILE,$(v))))

RMLUILIB=-L$(ANT3RD)/build/RmlUi/$(PLAT)/$(MODE) -lRmlDebugger -lRmlCore 
FONTLIB=-L../../bin/$(PLAT)/$(MODE) -lfont

$(ODIR)/rmlui.dll : $(ODIR)/luarmlui.o $(ODIR)/file.o $(ODIR)/font.o $(ODIR)/render.o $(ODIR)/system.o $(ODIR)/context.o $(ODIR)/fonteffect.o $(patsubst %,$(ODIR)/%.o, $(RMLLUA))
	$(CC) $(CFLAGS) $(LD_SHARED) -o $@ $^ $(RMLUILIB) $(FONTLIB) $(LUALIB) -lstdc++ 

$(ODIR)/librmlui.a : $(ODIR)/file.o $(ODIR)/font.o $(ODIR)/render.o $(ODIR)/system.o $(ODIR)/luarmlui.o
	ar rsv $@ $^

$(ODIR)/Lua/Elements :
	mkdir -p $@

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(ODIR) *.dll *.a
