ifeq ("$(BUILD_CONFIG)","Release")
LIB_SUFFIX := _r
else
LIB_SUFFIX := _d
endif
OZZLIBDIR = $(ANT3RD)/build/ozz-animation
OZZLIBSRC_DIR = $(OZZLIBDIR)/src
OZZBASE = -L $(OZZLIBSRC_DIR)/base -lozz_base$(LIB_SUFFIX)
OZZRUNTIME = -L $(OZZLIBSRC_DIR)/animation/runtime -lozz_animation$(LIB_SUFFIX)
OZZOFFLINE = -L $(OZZLIBSRC_DIR)/animation/offline -lozz_animation_offline$(LIB_SUFFIX)
OZZGEOMERTY = -L $(OZZLIBSRC_DIR)/geometry/runtime -lozz_geometry$(LIB_SUFFIX)
