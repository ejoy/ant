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

GLM_DIR = -I$(ANT3RD)/glm

OZZSAMPLE = -L $(OZZLIBDIR)/samples/framework -lsample_framework$(LIB_SUFFIX)

mingw : hierarchy.dll

hierarchy.o : hierarchy.cpp
	$(CXX) -c $(CXXFLAGS) -o $@ $^ $(LUALIB) $(LUAINC) $(GLM_DIR) $(OZZINC) $(OZZSAMPLE) $(OZZRUNTIME) $(OZZOFFLINE) $(OZZGEOMERTY) $(OZZBASE)

animation.o : animation.cpp
	$(CXX) -c $(CXXFLAGS) -o $@ $^ $(LUALIB) $(LUAINC) $(GLM_DIR) $(OZZINC) $(OZZSAMPLE) $(OZZRUNTIME) $(OZZOFFLINE) $(OZZGEOMERTY) $(OZZBASE)

hierarchy.dll : hierarchy.o animation.o
	$(CXX) --shared $(CXXFLAGS) -o $@ $^ $(LUALIB) $(LUAINC) $(GLM_DIR) $(OZZINC) $(OZZSAMPLE) $(OZZRUNTIME) $(OZZOFFLINE) $(OZZGEOMERTY) $(OZZBASE)

libhierarchy.a : hierarchy.o animation.o
	ar rsv $@ $^

clean :
	rm -f hierarchy.dll
