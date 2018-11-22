include ../common.mk
include ozz_define.mk

GLM_DIR = -I$(ANT3RD)/glm
OZZINC = -I $(ANT3RD) -I $(ANT3RD)/ozz-animation/include	

mingw : hierarchy.dll

OBJ_FILES := hierarchy.o animation.o ozz_mesh/mesh.o

hierarchy.o: hierarchy.cpp
	$(CXX) -c -std=c++17 -o $@ $< $(LUAINC) $(GLM_DIR) $(OZZINC)

animation.o: animation.cpp
	$(CXX) -c -std=c++17 -o $@ $< $(LUAINC) $(GLM_DIR) $(OZZINC)

ozz_mesh/mesh.o: ozz_mesh/mesh.cpp
	$(CXX) -c -std=c++17 -o $@ $< $(LUAINC) $(GLM_DIR) $(OZZINC)

hierarchy.dll : $(OBJ_FILES)
	$(CXX) --shared -lstdc++ -o $@ $^ $(LUALIB) $(LUAINC) $(GLM_DIR) $(OZZINC) $(OZZRUNTIME) $(OZZOFFLINE) $(OZZGEOMERTY) $(OZZBASE)

libhierarchy.a : $(OBJ_FILES)
	ar rsv $@ $^

clean :
	rm -f hierarchy.dll libhierarchy.a *.o
