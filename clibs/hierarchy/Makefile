include ../common.mk
include ozz_define.mk

GLM_DIR = -I$(ANT3RD)/glm
OZZINC = -I $(ANT3RD) -I $(ANT3RD)/ozz-animation/include	

ifeq "$(PLAT)" "mingw"
default : hierarchy.dll
else
default : libhierarchy.a
endif

OBJ_FILES := hierarchy.o animation.o ozz_mesh/mesh.o

hierarchy.o: hierarchy.cpp
	$(CXX) -c $(CFLAGS) -o $@ $< $(LUAINC) $(GLM_DIR) $(OZZINC)

animation.o: animation.cpp
	$(CXX) -c $(CFLAGS) -o $@ $< $(LUAINC) $(GLM_DIR) $(OZZINC)

ozz_mesh/mesh.o: ozz_mesh/mesh.cpp
	$(CXX) -c $(CFLAGS) -o $@ $< $(LUAINC) $(GLM_DIR) $(OZZINC)

hierarchy.dll : $(OBJ_FILES)
	$(CXX) $(LD_SHARED) -lstdc++ -o $@ $^ $(LUALIB) $(GLM_DIR) $(OZZINC) $(OZZRUNTIME) $(OZZOFFLINE) $(OZZGEOMERTY) $(OZZBASE)

libhierarchy.a : $(OBJ_FILES)
	ar rsv $@ $^

clean :
	rm -f hierarchy.dll libhierarchy.a $(OBJ_FILES)
