include ../common.mk

ifeq "$(PLAT)" "mingw"
default : font.dll
else
default : $(ODIR)/libbgfx.a
endif

STB_INCLUDE=-I$(ANT3RD)/bgfx/3rdparty/stb

font.dll : $(ODIR)/font.dll
	cp $< $@

$(ODIR) :
	mkdir -p $@

$(ODIR)/font_manager.o : font_manager.c | $(ODIR)
	$(CC) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $^ $(LUAINC) $(STB_INCLUDE)

$(ODIR)/font.dll : $(ODIR)/font_manager.o 
	$(CC) $(CFLAGS) $(LD_SHARED) -o $@ $^ $(LUALIB) -lstdc++

$(ODIR)/libfont.a : $(ODIR)/font_manager.o 
	ar rsv $@ $^

clean :
	rm -rf $(OROOT) *.dll *.a