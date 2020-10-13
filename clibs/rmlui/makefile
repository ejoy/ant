include ../common.mk

ifeq "$(PLAT)" "mingw"
default : rmlui.dll
else
default : $(ODIR)/librmlui.a
endif

rmlui.dll : $(ODIR)/rmlui.dll
	cp $< $@

# $(ODIR)/luafont.o : luafont.c | $(ODIR)
# 	$(CC) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $^ $(LUAINC) $(BGFX3RD_INC)

# $(ODIR)/font_manager.o : font_manager.c | $(ODIR)
# 	$(CC) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $^ $(LUAINC) $(BGFX3RD_INC)

# $(ODIR)/rmlui.dll : $(ODIR)/luafont.o $(ODIR)/font_manager.o
# 	$(CC) $(CFLAGS) $(LD_SHARED) -o $@ $^ $(LUALIB) -lstdc++

# $(ODIR)/librmlui.a : $(ODIR)/luafont.o $(ODIR)/font_manager.o
# 	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
