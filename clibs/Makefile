BIN = .
PLAT = mingw
LIBS := math3d lsocket redirectfd lfs bgfx remotedebug memoryfile \
 crypt assimplua hierarchy cppfs debugger thread protocol bullet

ALL_LIBS := $(LIBS) lua iup

.PHONY: $(ALL_LIBS) $(foreach v,$(ALL_LIBS),build_$(v) clean_$(v) copy_$(v))

IUPLIBS = iuplua scintilla iupluaimglib iupluacontrols
TARS = $(foreach v,$(LIBS) $(IUPLIBS),$(BIN)/$(v).dll)

#all : $(TARS) $(BIN)/iup.exe $(BIN)/lua53.dll $(BIN)/lua.exe 
all: $(ALL_LIBS)

## lua
copy_lua: build_lua
	cp lua/lua53.dll lua/lua.exe $(BIN)
build_lua:
	cd lua && $(MAKE) $(PLAT)
clean_lua:
	cd lua && $(MAKE) clean

IUP_DLL_NAMES := $(foreach v,$(IUPLIBS),iup/$(v).dll)
copy_iup: build_iup
	cp $(IUP_DLL_NAMES) iup/iup.exe $(BIN)

define TARG_func
$(1): build_$(1) copy_$(1)
endef

define COPY_DLL_func
$(BIN)/$(1).dll : copy_$(1)

copy_$(1): build_$(1)
	cp $(1)/$(1).dll $(BIN)/$(1).dll
endef

define MAKE_temp
build_$(1) : build_lua	
	cd $(1) && $(MAKE) $(PLAT)

clean_$(1) :
	cd $(1) && $(MAKE) clean
endef

$(foreach v, $(LIBS) iup, $(eval $(call MAKE_temp,$(v))))
$(foreach v, $(LIBS), $(eval $(call COPY_DLL_func,$(v))))

$(foreach v, $(LIBS) lua iup, $(eval $(call TARG_func,$(v))))

copy: $(addprefix copy_,$(LIBS) iup lua)
	
clean : $(addprefix clean_,$(LIBS) iup lua)
	rm -f *.dll && rm -f *.exe