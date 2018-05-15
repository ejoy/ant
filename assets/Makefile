OUT_DIR 	= ./build
LUABIN 		= ../clibs/lua/lua.exe
RENDERTYPE 	= d3d11

VERBOSE		= OFF

ROOT_DIR ?= $(dir $(shell pwd))
export ANTGE=$(ROOT_DIR)

ifeq ($(VERBOSE), ON)
$(info "export env var 'ANTGE' as $(ROOT_DIR) ")
endif


.PHONY : all
.PHONY : compileshader
.PHONY : copy_bin
.PHONY : clean

all : copy_bin
	
rwildcard=$(wildcard $1$2) $(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2))

SHADER_SRC 	:= shaders/src
SHADER_FILES := $(call rwildcard,$(SHADER_SRC)/,*.sc)
#SHADER_FILES := $(shell find $(SHADER_SRC) -name '*.sc')

#varying.def.sc file used for providing input var for vs and fs
SHADER_FILES := $(filter-out %/varying.def.sc,$(SHADER_FILES))

SHADER_DIRS := $(sort $(dir $(SHADER_FILES)))
TARGET_SHADERDIRS := $(addprefix $(OUT_DIR)/,$(SHADER_DIRS))
TARGET_SHADERFILES := $(patsubst %.sc,$(OUT_DIR)/%.bin,$(SHADER_FILES))

$(OUT_DIR):
	mkdir -p $(OUT_DIR)

$(TARGET_SHADERDIRS) : | $(OUT_DIR)
	mkdir -p $@

$(TARGET_SHADERFILES) : $(OUT_DIR)/%.bin : %.sc | $(TARGET_SHADERDIRS)
ifeq ($(VERBOSE), ON)
	@echo LUABIN: $(LUABIN), input file : $<, output file : $@, render type : $(RENDERTYPE)	
endif	
	$(LUABIN) ./shadercompile.lua $< $@ $(RENDERTYPE)

compileshader : $(TARGET_SHADERFILES)

# copy other files

BIN_RESOURCE_DIRS := meshes assetfiles
ALL_BIN_FILES := $(foreach p,$(BIN_RESOURCE_DIRS),$(call rwildcard,$p/,*))
TARGET_ALL_BIN_FILES := $(addprefix $(OUT_DIR)/,$(ALL_BIN_FILES))
TARGET_BIN_DIRS := $(sort $(dir $(TARGET_ALL_BIN_FILES)))

$(TARGET_BIN_DIRS) : | $(OUT_DIR)
	mkdir -p $@

$(TARGET_ALL_BIN_FILES) : $(OUT_DIR)/% : % | $(TARGET_BIN_DIRS)
	cp $^ $@

copy_bin: $(TARGET_ALL_BIN_FILES)
	
clean :
	rm -Rf $(OUT_DIR)