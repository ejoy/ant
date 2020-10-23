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
	$(CXX) -c $(CFLAGS) -o $@ $^ $(LUAINC) $(RMLUIINC)

$(ODIR)/font.o : font.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ $(LUAINC) $(CLIBSINC) $(BGFX3RDINC) $(BGFXINC) $(RMLUIINC)

$(ODIR)/render.o : render.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ $(LUAINC) $(CLIBSINC) $(BGFX3RDINC) $(BGFXINC) $(RMLUIINC)

$(ODIR)/system.o : system.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ $(LUAINC) $(CLIBSINC) $(BGFX3RDINC) $(BGFXINC) $(RMLUIINC)

$(ODIR)/luarmlui.o : luarmlui.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ $(LUAINC) $(CLIBSINC) $(BGFX3RDINC) $(BGFXINC) $(RMLUIINC)

RMLUILIB=-L$(ANT3RD)/build/RmlUi/$(PLAT)/$(MODE) -lRmlCore
FONTLIB=-L../../bin/$(PLAT)/$(MODE) -lfont

$(ODIR)/rmlui.dll : $(ODIR)/luarmlui.o $(ODIR)/file.o $(ODIR)/font.o $(ODIR)/render.o $(ODIR)/system.o
	$(CC) $(CFLAGS) $(LD_SHARED) -o $@ $^ $(RMLUILIB) $(FONTLIB) $(LUALIB) -lstdc++ 

$(ODIR)/librmlui.a : $(ODIR)/file.o $(ODIR)/font.o $(ODIR)/render.o $(ODIR)/system.o $(ODIR)/luarmlui.o
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
