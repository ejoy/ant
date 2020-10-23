BIN = ../bin/$(PLAT)/$(MODE)
LIBS := math3d lsocket bgfx filesystem remotedebug \
 crypt hierarchy thread protocol \
 window filewatch platform subprocess datalist imgui terrain firmware rp3d image font rmlui

ALL_LIBS := lua $(LIBS)

include common.mk

.PHONY: $(ALL_LIBS) $(foreach v,$(ALL_LIBS),build_$(v) clean_$(v) copy_$(v))

all: $(ALL_LIBS)

LUA_TARGETS = $(ODIR)/lua.exe
ifeq "$(PLAT)" "msvc"
LUA_TARGETS += $(ODIR)/lua54.dll
else ifeq "$(PLAT)" "mingw"
LUA_TARGETS += $(ODIR)/lua54.dll
endif

copy_lua: build_lua
	cp $(addprefix lua/,$(LUA_TARGETS)) $(BIN)
build_lua:
	$(MAKE) -C lua $(LUA_TARGETS)
clean_lua:
	$(MAKE) -C lua clean

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
