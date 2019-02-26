include ../common.mk

ANT3RD = ../../3rd
include ant_define.mk

ifeq "$(PLAT)" "mingw"
default : ant.exe
else
default : libant-$(PLAT).a
endif

LIBS= bgfx bullet hierarchy math3d thread terrain crypt lsocket protocol remotedebug firmware platform window datalist

define MakeLibs
$(ODIR)/lib$(1).a : | $(ODIR)
	@cd ../$(1)/ && $(MAKE) --no-print-directory lib$(1)-$(PLAT).a && cp lib$(1)-$(PLAT).a ../ant/$(ODIR)/lib$(1).a
unpack_lib$(1).a : $(ODIR)/lib$(1).a 
	@cd $(ODIR) && ar x lib$(1).a && rm -f lib$(1).a
endef
$(foreach v, $(LIBS), $(eval $(call MakeLibs,$(v))))

LIBS2= ib-compress cjson lua
define UnpackLibs2
unpack_lib$(1).a : $(ODIR)/lib$(1).a
	@cd $(ODIR) && ar x lib$(1).a
endef
$(foreach v, $(LIBS2), $(eval $(call UnpackLibs2,$(v))))

UNPACKLIBS= $(foreach v, $(LIBS), unpack_lib$(v).a) $(foreach v, $(LIBS2), unpack_lib$(v).a)


$(ODIR)/liblua.a : | $(ODIR)
	@$(MAKE) --no-print-directory -f Makefile.lua

$(ODIR)/libcjson.a : | $(ODIR)
	@$(MAKE) -f Makefile.cjson

$(ODIR)/libib-compress.a : | $(ODIR)
	@cd ../../3rd/ib-compress/ && $(MAKE) --no-print-directory libib-compress-$(PLAT).a "ODIR=$(ODIR)" "PLAT=$(PLAT)" && mv libib-compress-$(PLAT).a ../../clibs/ant/$(ODIR)/libib-compress.a

$(ODIR)/ant_searcher.o : ant_searcher.c ant.h ant_module_define.h ant_module_declar.h | $(ODIR)
	$(CC) -c $(CFLAGS) $(LUAINC) -o $@ $<

$(ODIR)/main.o : main.c | $(ODIR)
	$(CC) -c $(CFLAGS) $(LUAINC) -o $@ $<

libant-$(PLAT).a : $(ODIR)/ant_searcher.o $(UNPACKLIBS)
	rm -f "$(ODIR)/__.SYMDEF"
	rm -f "$(ODIR)/__.SYMDEF SORTED"
	cd $(ODIR) && ar rs $@ *.o
	mv $(ODIR)/$@ $@

ant.exe : $(ODIR)/main.o libant-$(PLAT).a
	gcc -o $@ $^ $(LINKLIBANT)
	$(STRIP) $@ 

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.exe *.a