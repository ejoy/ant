include ../common.mk
include ../bgfx/bgfx_define.mk

ASSIMPROOT = $(ANT3RD)
ASSIMPINC = -I$(ASSIMPROOT)/assimp/include -I$(ANT3RD)/build/assimp/include
ASSIMPLIB = -L$(ASSIMPROOT)/build/assimp/code -lassimp -L$(ASSIMPROOT)/build/assimp/contrib/irrXML -lIrrXML -lz

mingw : assimplua.dll

GLM_INC := -I$(ANT3RD)/glm
$(ODIR) : 
	mkdir $@

SRC_FILES := assimplua.cpp antmesh_converter.cpp fbx_helper.cpp bgfxmesh_helper.cpp utils.cpp
OBJ_FILES := $(patsubst %.cpp,$(ODIR)/%.o,$(SRC_FILES))

$(OBJ_FILES) : $(ODIR)/%.o : %.cpp | $(ODIR)
	$(CXX) $(CFLAGS) $(CXXFLAGS) -c -o $@ $^ -L. $(LUAINC) $(ASSIMPINC) $(BGFXINC) $(GLM_INC)
	
assimplua.dll : $(OBJ_FILES)
	$(CXX) $(CFLAGS) $(CXXFLAGS) --shared -o $@ $^ -L. $(LUALIB) $(ASSIMPLIB) $(BGFXUTILLIB) $(BGFXLIB) $(BIMG_DECODELIB)

clean :
	rm -f assimplua.dll && rm -rf o