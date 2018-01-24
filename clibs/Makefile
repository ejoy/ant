BIN = .
LIBS = math3d lsocket
PLAT = mingw

DLLS = $(foreach v, $(LIBS), $(v)/$(v).dll)
TARS = $(foreach v, $(LIBS), $(BIN)/$(v).dll)

all : $(TARS) $(BIN)/lua53.dll

lua/lua53.dll :
	cd lua && $(MAKE) $(PLAT)

$(BIN)/lua53.dll : lua/lua53.dll
	cp $< $@

$(DLLS) : %.dll :
	cd $(dir $@) && $(MAKE) $(PLAT)

define COPY_temp
$(BIN)/$(1).dll : $(1)/$(1).dll
	cp $$< $$@
endef

$(foreach v, $(LIBS), $(eval $(call COPY_temp,$(v))))

clean :
	rm -f *.dll