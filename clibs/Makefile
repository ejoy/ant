BIN = .
LIBS := math3d lsocket bgfx filesystem remotedebug \
 crypt meshconverter hierarchy thread protocol bullet \
 window filewatch platform subprocess datalist imgui terrain firmware

ALL_LIBS := lua $(LIBS)

include common.mk

.PHONY: $(ALL_LIBS) $(foreach v,$(ALL_LIBS),build_$(v) clean_$(v) copy_$(v)) copy_tools

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

ifeq "$(PLAT)" "osx"
BGFX_BUILD_PLAT_NAME = osx64_clang/bin

else ifeq "$(PLAT)" "mingw"
BGFX_BUILD_PLAT_NAME = win64_mingw-gcc/bin
TOOL_EXT_NAME=.exe
else ifeq "$(PLAT)" "msvc"
BGFX_BUILD_PLAT_NAME = win64_vs2019/bin
TOOL_EXT_NAME=.exe
else
$(error "$(PLAT) not support copy tool")
endif
BGFX_BUILD_PATH = ../3rd/bgfx/.build

ifeq "$(MODE)" "debug"
SHADER_TOOLNAME=shadercDebug$(TOOL_EXT_NAME)
TEXTURE_TOOLNAME=texturecDebug$(TOOL_EXT_NAME)
else
SHADER_TOOLNAME=shadercRelease$(TOOL_EXT_NAME)
TEXTURE_TOOLNAME=texturecRelease$(TOOL_EXT_NAME)
endif

copy_tools:
	cp $(BGFX_BUILD_PATH)/$(BGFX_BUILD_PLAT_NAME)/$(SHADER_TOOLNAME) $(BIN)/$(SHADER_TOOLNAME) &&\
	cp $(BGFX_BUILD_PATH)/$(BGFX_BUILD_PLAT_NAME)/$(TEXTURE_TOOLNAME) $(BIN)/$(TEXTURE_TOOLNAME)

copy: $(addprefix copy_,$(ALL_LIBS)) copy_tools
	
clean : $(addprefix clean_,$(ALL_LIBS))
	rm -f *.dll && rm -f *.exe
