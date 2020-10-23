include ../common.mk

ifeq "$(PLAT)" "mingw"
default : font.dll
else
default : $(ODIR)/libfont.a
endif

font.dll : $(ODIR)/font.dll
	cp $< $@

BGFX3RD_INC=-I$(ANT3RD)/bgfx/3rdparty

$(ODIR)/luafont.o : luafont.c | $(ODIR)
	$(CC) $(CFLAGS) -c $(LUA_FLAGS) -DFONT_EXPORT -o $@ $^ $(LUAINC) $(BGFX3RD_INC)

$(ODIR)/font_manager.o : font_manager.c | $(ODIR)
	$(CC) $(CFLAGS) -c $(LUA_FLAGS) -DFONT_EXPORT -o $@ $^ $(LUAINC) $(BGFX3RD_INC)

$(ODIR)/font.dll : $(ODIR)/luafont.o $(ODIR)/font_manager.o
	$(CC) $(CFLAGS) $(LD_SHARED) -DFONT_EXPORT -o $@ $^ $(LUALIB) -lstdc++

$(ODIR)/libfont.a : $(ODIR)/luafont.o $(ODIR)/font_manager.o
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
