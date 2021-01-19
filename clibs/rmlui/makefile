include ../common.mk
include ../bgfx/bgfx_define.mk

ifeq "$(PLAT)" "mingw"
default : rmlui.dll
else
default : $(ODIR)/librmlui.a
endif

rmlui.dll : $(ODIR)/rmlui.dll
	cp $< $@

RMLUIINC=-I$(ANT3RD)/RmlUi/Include -I$(ANT3RD)/yoga

$(ODIR)/file.o : file.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ -DRMLUI_STATIC_LIB $(LUAINC) $(RMLUIINC) $(BGFXINC)

$(ODIR)/font.o : font.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ -DRMLUI_STATIC_LIB $(LUAINC) $(BGFX3RDINC) $(BGFXINC) $(RMLUIINC)

$(ODIR)/render.o : render.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ -DRMLUI_STATIC_LIB $(LUAINC) $(BGFX3RDINC) $(BGFXINC) $(RMLUIINC)

$(ODIR)/system.o : system.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ -DRMLUI_STATIC_LIB $(LUAINC) $(BGFX3RDINC) $(BGFXINC) $(RMLUIINC)

$(ODIR)/binding_context.o : binding_context.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ -DRMLUI_STATIC_LIB $(LUAINC) $(BGFX3RDINC) $(BGFXINC) $(RMLUIINC)

$(ODIR)/binding_fonteffect.o : binding_fonteffect.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ -DRMLUI_STATIC_LIB $(LUAINC) $(BGFX3RDINC) $(BGFXINC) $(RMLUIINC)

$(ODIR)/luarmlui.o : luarmlui.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ -DRMLUI_STATIC_LIB $(LUAINC) $(BGFX3RDINC) $(BGFXINC) $(RMLUIINC)

$(ODIR)/luaplugin.o : luaplugin.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ -DRMLUI_STATIC_LIB $(LUAINC) $(BGFX3RDINC) $(BGFXINC) $(RMLUIINC)
	
$(ODIR)/luadatabinding.o : luadatabinding.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ -DRMLUI_STATIC_LIB $(LUAINC) $(BGFX3RDINC) $(BGFXINC) $(RMLUIINC)

$(ODIR)/rmlapi.o : rmlapi.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ -DRMLUI_STATIC_LIB $(LUAINC) $(BGFX3RDINC) $(BGFXINC) $(RMLUIINC)

RMLUI_DIR = $(ANT3RD)/RmlUi/Source
RMLUI = $(patsubst $(RMLUI_DIR)/%.cpp,%,$(wildcard $(RMLUI_DIR)/*.cpp))
define RMLUI_COMPLILE
$(ODIR)/$(1).o : $(RMLUI_DIR)/$(1).cpp
	$(CXX) -c $(CFLAGS) -o $$@ $$^ -DRMLUI_STATIC_LIB $(LUAINC) $(RMLUIINC)
endef
$(foreach v, $(RMLUI), $(eval $(call RMLUI_COMPLILE,$(v))))

YOGA_DIR = $(ANT3RD)/yoga/yoga
YOGA = $(patsubst $(YOGA_DIR)/%.cpp,%,$(wildcard $(YOGA_DIR)/*.cpp)) event/event
define YOGA_COMPLILE
$(ODIR)/yoga/$(1).o : $(YOGA_DIR)/$(1).cpp | $(ODIR)/yoga/event
	$(CXX) -c $(CFLAGS) -o $$@ $$^ $(LUAINC) -I$(ANT3RD)/yoga -DDEBUG
endef
$(foreach v, $(YOGA), $(eval $(call YOGA_COMPLILE,$(v))))

FONTLIB=-L../../bin/$(PLAT)/$(MODE) -lfont

OBJS = $(ODIR)/luarmlui.o $(ODIR)/luaplugin.o $(ODIR)/luadatabinding.o $(ODIR)/rmlapi.o $(ODIR)/file.o $(ODIR)/font.o $(ODIR)/render.o $(ODIR)/system.o $(ODIR)/binding_context.o $(ODIR)/binding_fonteffect.o $(patsubst %,$(ODIR)/%.o, $(RMLUI)) $(patsubst %,$(ODIR)/yoga/%.o, $(YOGA))
$(ODIR)/rmlui.dll : $(OBJS)
	$(CC) $(CFLAGS) $(LD_SHARED) -o $@ $^ $(FONTLIB) $(LUALIB) -lstdc++ 

$(ODIR)/librmlui.a : $(OBJS)
	ar rsv $@ $^

$(ODIR)/yoga/event :
	mkdir -p $@

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(ODIR) *.dll *.a
