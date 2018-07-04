LUAINC = -I ../lua
LUALIB = -L ../lua -llua53
CXXFLAGS = -O2 -Wall
OZZLIBDIR = ../../../ant3rd/build/ozz-animation/src
OZZINC = -I ../../../ant3rd/ozz-animation/include
OZZBASE = -L $(OZZLIBDIR)/base -lozz_base
OZZRUNTIME = -L $(OZZLIBDIR)/animation/runtime -lozz_animation
OZZOFFLINE = -L $(OZZLIBDIR)/animation/offline -lozz_animation_offline
CXX = g++

mingw : hierarchy.dll

hierarchy.dll : hierarchy.cpp
	$(CXX) --shared $(CXXFLAGS) -o $@ $^ $(LUALIB) $(LUAINC) $(OZZINC) $(OZZRUNTIME) $(OZZOFFLINE) $(OZZBASE)

clean :
	rm -f hierarchy.dll
