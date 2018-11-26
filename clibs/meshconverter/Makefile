include ../common.mk
include ../bgfx/bgfx_define.mk

ASSIMPROOT = $(ANT3RD)
ASSIMPINC = -I$(ASSIMPROOT)/assimp/include -I$(ANT3RD)/build/assimp/include
ASSIMPLIB = -L$(ASSIMPROOT)/build/assimp/code -lassimp -L$(ASSIMPROOT)/build/assimp/contrib/irrXML -lIrrXML -lz

mingw : meshconverter.dll

GLM_INC := -I$(ANT3RD)/glm
$(ODIR) : 
	mkdir $@

SRC_FILES := meshconverter.cpp antmesh_converter.cpp fbx_helper.cpp bgfxmesh_helper.cpp utils.cpp
OBJ_FILES := $(patsubst %.cpp,$(ODIR)/%.o,$(SRC_FILES))

$(OBJ_FILES) : $(ODIR)/%.o : %.cpp | $(ODIR)
	$(CXX) $(CFLAGS) -std=c++17 -c -o $@ $^ $(LUAINC) $(ASSIMPINC) $(BGFXINC) $(GLM_INC)
	
meshconverter.dll : $(OBJ_FILES)
	$(CXX) $(CFLAGS) -lstdc++ $(LD_SHARED) -o $@ $^ -L. $(LUALIB) $(ASSIMPLIB) $(BGFXUTILLIB) $(BGFXLIB) $(BIMG_DECODELIB)

clean :
	rm -f meshconverter.dll && rm -rf o