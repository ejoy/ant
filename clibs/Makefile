BIN = .
LIBS := math3d lsocket bgfx filesystem remotedebug \
 crypt meshconverter hierarchy thread protocol bullet \
 window filewatch platform subprocess datalist imgui terrain

ALL_LIBS := $(LIBS) lua bgfx_core

include common.mk

.PHONY: $(ALL_LIBS) $(foreach v,$(ALL_LIBS),build_$(v) clean_$(v) copy_$(v))

all: $(ALL_LIBS)

copy_lua: build_lua
	cp lua/$(ODIR)/lua53.dll lua/$(ODIR)/lua.exe $(BIN)
build_lua:
	$(MAKE) -C lua $(ODIR)/lua53.dll $(ODIR)/lua.exe
clean_lua:
	$(MAKE) -C lua clean

copy_bgfx_core: build_bgfx
	cp bgfx/$(ODIR)/bgfx-core.dll $(BIN)

build_bgfx_core: build_bgfx

clean_bgfx_core: clean_bgfx

define TARG_func
$(1): build_$(1) copy_$(1)
endef

define COPY_DLL_func
$(BIN)/$(1).dll : copy_$(1)

copy_$(1): build_$(1)
	cp $(1)/$(ODIR)/$(1).dll $(BIN)/$(1).dll
endef

define MAKE_temp
build_$(1) : build_lua
	$(MAKE) -C $(1) $(ODIR)/$(1).dll

clean_$(1) :
	$(MAKE) -C $(1) clean
endef

$(foreach v, $(LIBS), $(eval $(call MAKE_temp,$(v))))
$(foreach v, $(LIBS), $(eval $(call COPY_DLL_func,$(v))))
$(foreach v, $(ALL_LIBS), $(eval $(call TARG_func,$(v))))

copy: $(addprefix copy_,$(ALL_LIBS))
	
clean : $(addprefix clean_,$(ALL_LIBS))
	rm -f *.dll && rm -f *.exe
