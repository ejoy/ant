include ../common.mk
include ozz_define.mk

GLM_DIR = -I$(ANT3RD)/glm
OZZINC = -I $(ANT3RD) -I $(ANT3RD)/ozz-animation/include	

mingw : hierarchy.dll

SRC_FILES := hierarchy.cpp animation.cpp ozz_mesh/mesh.cpp

OBJ_FILES := $(patsubst %.c,%.o,$(SRC_FILES))


$(OBJ_FILES): %.o: %.cpp
	$(CXX) -c $(CXXFLAGS) -o $@ $^ $(LUALIB) $(LUAINC) $(GLM_DIR) $(OZZINC) $(OZZRUNTIME) $(OZZOFFLINE) $(OZZGEOMERTY) $(OZZBASE)

hierarchy.dll : $(OBJ_FILES)
	$(CXX) --shared $(CXXFLAGS) -o $@ $^ $(LUALIB) $(LUAINC) $(GLM_DIR) $(OZZINC) $(OZZRUNTIME) $(OZZOFFLINE) $(OZZGEOMERTY) $(OZZBASE)

libhierarchy.a : $(OBJ_FILES)
	ar rsv $@ $^

clean :
	rm -f hierarchy.dll
