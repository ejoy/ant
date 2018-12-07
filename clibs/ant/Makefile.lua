include ../common.mk

default: $(ODIR)/liblua.a

LUADIR=../lua
CPLAT := $(PLAT)

include ../lua/Makefile

define build_lua
$(LUADIR)/$(ODIR)/$(1) : $(LUADIR)/$(subst .o,.c,$(1))  | $(LUADIR)/$(ODIR)
	$(CC) -c $(CFLAGS) -o $(LUADIR)/$(ODIR)/$(1) $(LUADIR)/$(subst .o,.c,$(1))
endef
$(foreach v, $(BASE_O), $(eval $(call build_lua,$(v))))

$(LUADIR)/liblua-$(CPLAT).a : $(foreach v, $(BASE_O), $(LUADIR)/$(ODIR)/$(v))
	ar rsv $@ $^

$(ODIR)/liblua.a : $(LUADIR)/liblua-$(CPLAT).a
	cp $< $@

$(LUADIR)/$(ODIR) :
	mkdir -p $@
