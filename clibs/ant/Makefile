include ../common.mk

ANT3RD = ../../3rd
include ant_define.mk

ifeq "$(PLAT)" "mingw"
default : ant.exe
else
default : libant.a
endif

LIBS= lua bgfx bullet hierarchy math3d thread terrain crypt lsocket protocol remotedebug firmware platform window datalist filesystem meshconverter imgui

define MakeLibs

$(ODIR)/lib$(1).a : ../$(1)/$(ODIR)/lib$(1).a | $(ODIR)
	@$(MAKE) --no-print-directory -C ../$(1) $(ODIR)/lib$(1).a && cp ../$(1)/$(ODIR)/lib$(1).a $(ODIR)/lib$(1).a && cd $(ODIR) && ar x lib$(1).a && rm -f lib$(1).a

unpack_lib$(1).a : $(ODIR)/lib$(1).a | $(ODIR)

endef
$(foreach v, $(LIBS), $(eval $(call MakeLibs,$(v))))

UNPACKLIBS= $(foreach v, $(LIBS), unpack_lib$(v).a)

$(ODIR)/ant_searcher.o : ant_searcher.c ant.h ant_module_define.h ant_module_declar.h | $(ODIR)
	$(CC) -c $(CFLAGS) $(LUAINC) $(BGFXINC) -o $@ $<

$(ODIR)/main.o : main.c | $(ODIR)
	$(CC) -c $(CFLAGS) $(LUAINC) -o $@ $<

$(ODIR)/libant.a : $(ODIR)/ant_searcher.o $(UNPACKLIBS)
	rm -f "$(ODIR)/__.SYMDEF"
	rm -f "$(ODIR)/__.SYMDEF SORTED"
	cd $(ODIR) && ar rs libant.a *.o

libant.a : $(ODIR)/libant.a
	cp $(ODIR)/$@ $@

ant.exe : $(ODIR)/main.o $(ODIR)/libant.a
	$(CC) -o $@ $^ $(LINKLIBANT) && $(STRIP) $@

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.exe *.a