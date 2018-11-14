include ../common.mk
include ozz_define.mk

GLM_DIR = -I$(ANT3RD)/glm
OZZINC = -I $(ANT3RD) -I $(ANT3RD)/ozz-animation/include	

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
