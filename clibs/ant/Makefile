include ../common.mk

ANT3RD = ../../3rd
include ant_define.mk

default : libant.a

LIBS= lua bgfx hierarchy math3d thread terrain crypt lsocket protocol remotedebug firmware platform window datalist filesystem rp3d

define MakeLibs

$(ODIR)/lib$(1).a : | $(ODIR)
	@$(MAKE) --no-print-directory -C ../$(1) $(ODIR)/lib$(1).a && cp ../$(1)/$(ODIR)/lib$(1).a $(ODIR)/lib$(1).a && cd $(ODIR) && ar x lib$(1).a && rm -f lib$(1).a

unpack_lib$(1).a : $(ODIR)/lib$(1).a | $(ODIR)

endef
$(foreach v, $(LIBS), $(eval $(call MakeLibs,$(v))))

UNPACKLIBS= $(foreach v, $(LIBS), unpack_lib$(v).a)

$(ODIR)/libant.a : $(UNPACKLIBS)
	rm -f "$(ODIR)/__.SYMDEF"
	rm -f "$(ODIR)/__.SYMDEF SORTED"
	cd $(ODIR) && ar rs libant.a *.o

libant.a : $(ODIR)/libant.a
	cp $(ODIR)/$@ $@

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.exe *.a
