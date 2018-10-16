LUAINC = -I ../lua
LUALIB = -L ../lua -llua53
CXXFLAGS = -O2 -Wall -lstdc++

OZZLIBDIR = ../../../ant3rd/build/ozz-animation
OZZLIBSRC_DIR = $(OZZLIBDIR)/src
OZZINC = -I ../../../ant3rd -I ../../../ant3rd/ozz-animation/include
OZZBASE = -L $(OZZLIBSRC_DIR)/base -lozz_base
OZZRUNTIME = -L $(OZZLIBSRC_DIR)/animation/runtime -lozz_animation
OZZOFFLINE = -L $(OZZLIBSRC_DIR)/animation/offline -lozz_animation_offline
OZZGEOMERTY = -L $(OZZLIBSRC_DIR)/geometry/runtime -lozz_geometry

OZZSAMPLE = -L $(OZZLIBDIR)/samples/framework -lsample_framework
CXX = g++

mingw : hierarchy.dll

hierarchy.dll : hierarchy.cpp animation.cpp
	$(CXX) --shared $(CXXFLAGS) -o $@ $^ $(LUALIB) $(LUAINC) $(OZZINC) $(OZZSAMPLE) $(OZZRUNTIME) $(OZZOFFLINE) $(OZZGEOMERTY) $(OZZBASE)

clean :
	rm -f hierarchy.dll
