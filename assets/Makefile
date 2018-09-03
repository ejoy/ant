OUT_DIR 		= ./build
LUABIN 			= ../clibs/lua/lua.exe
SHADER_TYPE_PATH= dx11
RENDER_TYPE		= d3d11

VERBOSE		= OFF

ROOT_DIR ?= $(dir $(shell pwd))
export ANTGE=$(ROOT_DIR)

ifeq ($(VERBOSE), ON)
$(info "export env var 'ANTGE' as $(ROOT_DIR) ")
endif


.PHONY : all compileshader make_lnkfiles copy_bin

all : compileshader copy_bin
	
rwildcard=$(wildcard $1$2) $(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2))

SHADER_PATH 	:= shaders
SHADER_SRC_PATH := $(SHADER_PATH)/src
OUT_SHADER_PATH := $(OUT_DIR)/$(SHADER_PATH)/$(SHADER_TYPE_PATH)

SHADER_FILES := $(call rwildcard,$(SHADER_SRC_PATH)/,*.sc)
#SHADER_FILES := $(shell find $(SHADER_SRC) -name '*.sc')

#varying.def.sc file used for providing input var for vs and fs
SHADER_FILES := $(filter-out %/varying.def.sc,$(SHADER_FILES))

SHADER_DIRS := $(sort $(dir $(SHADER_FILES)))
TARGET_SHADERFILES := $(patsubst $(SHADER_SRC_PATH)/%.sc,$(OUT_SHADER_PATH)/%.bin,$(SHADER_FILES))
TARGET_SHADERDIRS := $(sort $(dir $(TARGET_SHADERFILES)))

BIN_RESOURCE_DIRS := meshes assetfiles maps textures hierarchy
ALL_BIN_FILES := $(foreach p,$(BIN_RESOURCE_DIRS),$(call rwildcard,$p/,*.*))
TARGET_ALL_BIN_FILES := $(addprefix $(OUT_DIR)/,$(ALL_BIN_FILES))
TARGET_BIN_DIRS := $(sort $(dir $(TARGET_ALL_BIN_FILES)))

TARGET_DIRS := $(TARGET_SHADERDIRS) $(TARGET_BIN_DIRS)
TARGET_DIRS := $(sort $(TARGET_DIRS))

ifeq ($(VERBOSE), ON)
$(info "OUTPUT SHADER PATH : " $(OUT_SHADER_PATH))
$(info "SHADER SC FILES : " $(SHADER_FILES))
$(info "TARGET SHADERFILES : " $(TARGET_SHADERFILES))
$(info "TARGET SHADER DIRS : " $(TARGET_SHADERDIRS))
$(info "TARGET BIN FILES : " $(TARGET_ALL_BIN_FILES))
$(info "TARGET BIN DIRS : " $(TARGET_BIN_DIRS))
endif

$(OUT_DIR):
	mkdir -p $(OUT_DIR)

$(TARGET_DIRS) : | $(OUT_DIR)
	mkdir -p $@

$(TARGET_SHADERFILES) : $(OUT_SHADER_PATH)/%.bin : $(SHADER_SRC_PATH)/%.sc | $(TARGET_DIRS)
ifeq ($(VERBOSE), ON)
	@echo LUABIN: $(LUABIN), input file : $<, output file : $@, render type : $(SHADER_TYPE_PATH)	
endif	
	$(LUABIN) ./shadercompile.lua $< $@ $(RENDER_TYPE)

compileshader : $(TARGET_SHADERFILES)


LNK_FILES := $(addsuffix .lnk,$(SHADER_FILES))

make_lnkfiles: $(LNK_FILES)

$(LNK_FILES) : %.lnk : %
	$(LUABIN) ./make_lnkfile.lua $^


# copy other files
$(TARGET_ALL_BIN_FILES) : $(OUT_DIR)/% : % | $(TARGET_DIRS)
	cp $^ $@

copy_bin: $(TARGET_ALL_BIN_FILES)
	

.PHONY : clean clean_shaders clean_bin clean_lnkfiles

clean_lnkfiles:
	for lnkfile in $(LNK_FILES); do rm -Rf $$lnkfile; done

clean_shaders:
	rm -Rf $(OUT_DIR)/$(SHADER_PATH)

clean_bin:	
	for v in $(BIN_RESOURCE_DIRS); do rm -Rf $(OUT_DIR)/$$v; done

clean :
	rm -Rf $(OUT_DIR)