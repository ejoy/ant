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

$(ODIR)/luaplugin.o : luaplugin.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ -DRMLUI_STATIC_LIB $(LUAINC) $(CLIBSINC) $(RMLUIINC)

$(ODIR)/rmlapi.o : rmlapi.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ -DRMLUI_STATIC_LIB $(LUAINC) $(CLIBSINC) $(RMLUIINC)

RMLUILIB=-L$(ANT3RD)/build/RmlUi/$(PLAT)/$(MODE) -lRmlDebugger -lRmlCore 
FONTLIB=-L../../bin/$(PLAT)/$(MODE) -lfont

$(ODIR)/rmlui.dll : $(ODIR)/luarmlui.o $(ODIR)/luaplugin.o $(ODIR)/rmlapi.o $(ODIR)/file.o $(ODIR)/font.o $(ODIR)/render.o $(ODIR)/system.o $(ODIR)/context.o $(ODIR)/fonteffect.o
	$(CC) $(CFLAGS) $(LD_SHARED) -o $@ $^ $(RMLUILIB) $(FONTLIB) $(LUALIB) -lstdc++ 

$(ODIR)/librmlui.a : $(ODIR)/file.o $(ODIR)/font.o $(ODIR)/render.o $(ODIR)/system.o $(ODIR)/luarmlui.o $(ODIR)/luaplugin.o $(ODIR)/rmlapi.o
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(ODIR) *.dll *.a
