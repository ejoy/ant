BIN = .
LIBS := math3d lsocket redirectfd bgfx filesystem remotedebug \
 crypt meshconverter hierarchy thread protocol bullet \
 window filewatch platform subprocess datalist imgui

ALL_LIBS := $(LIBS) lua

include common.mk

.PHONY: $(ALL_LIBS) $(foreach v,$(ALL_LIBS),build_$(v) clean_$(v) copy_$(v))

TARS = $(foreach v,$(LIBS) $(IUPLIBS),$(BIN)/$(v).dll)

all: $(ALL_LIBS)

## lua
copy_lua: build_lua
	cp lua/lua53.dll lua/lua.exe $(BIN)
build_lua:
	cd lua && $(MAKE) "PLAT=$(PLAT)" lua53.dll lua.exe
clean_lua:
	cd lua && $(MAKE) clean

define TARG_func
$(1): build_$(1) copy_$(1)
endef

define COPY_DLL_func
$(BIN)/$(1).dll : copy_$(1)

copy_$(1): build_$(1)
	cp $(1)/$(1).dll $(BIN)/$(1).dll
endef

copy_bgfx-core: build_bgfx
	cp bgfx/bgfx-core.dll $(BIN)/bgfx-core.dll

define MAKE_temp
build_$(1) : build_lua
	cd $(1) && $(MAKE) "PLAT=$(PLAT)"

clean_$(1) :
	cd $(1) && $(MAKE) clean
endef

$(foreach v, $(LIBS), $(eval $(call MAKE_temp,$(v))))
$(foreach v, $(LIBS), $(eval $(call COPY_DLL_func,$(v))))

$(foreach v, $(LIBS) lua, $(eval $(call TARG_func,$(v))))

copy: $(addprefix copy_,$(LIBS) lua bgfx-core)
	
clean : $(addprefix clean_,$(LIBS) lua)
	rm -f *.dll && rm -f *.exe