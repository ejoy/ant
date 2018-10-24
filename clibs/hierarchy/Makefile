include ../common.mk

ifeq ("$(BUILD_CONFIG)","Release")
LIB_SUFFIX := _r
else
LIB_SUFFIX := _d
endif

OZZLIBDIR = $(ANT3RD)/build/ozz-animation
OZZLIBSRC_DIR = $(OZZLIBDIR)/src
OZZINC = -I $(ANT3RD) -I $(ANT3RD)/ozz-animation/include
OZZBASE = -L $(OZZLIBSRC_DIR)/base -lozz_base$(LIB_SUFFIX)
OZZRUNTIME = -L $(OZZLIBSRC_DIR)/animation/runtime -lozz_animation$(LIB_SUFFIX)
OZZOFFLINE = -L $(OZZLIBSRC_DIR)/animation/offline -lozz_animation_offline$(LIB_SUFFIX)
OZZGEOMERTY = -L $(OZZLIBSRC_DIR)/geometry/runtime -lozz_geometry$(LIB_SUFFIX)

OZZSAMPLE = -L $(OZZLIBDIR)/samples/framework -lsample_framework$(LIB_SUFFIX)

mingw : hierarchy.dll

hierarchy.dll : hierarchy.cpp animation.cpp
	$(CXX) --shared $(CXXFLAGS) -o $@ $^ $(LUALIB) $(LUAINC) $(OZZINC) $(OZZSAMPLE) $(OZZRUNTIME) $(OZZOFFLINE) $(OZZGEOMERTY) $(OZZBASE)

clean :
	rm -f hierarchy.dll
