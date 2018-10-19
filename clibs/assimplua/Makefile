include ../common.mk
include ../bgfx/bgfx_define.mk

ASSIMPROOT = $(ANT3RD)
ASSIMPINC = -I$(ASSIMPROOT)/assimp/include -I$(ANT3RD)/build/assimp/include
ASSIMPLIB = -L$(ASSIMPROOT)/build/assimp/code -lassimp -L$(ASSIMPROOT)/build/assimp/contrib/irrXML -lIrrXML -lz

# OZZINC = -I $(ANT3RD) -I$(ANT3RD)/ozz-animation/include

# OZZLIBDIR = $(ANT3RD)/build/ozz-animation

# OZZLIB = -L$(OZZLIBDIR)/samples/framework  -lsample_framework
# OZZLIB += -L$(OZZLIBDIR)/src/animation/offline -lozz_animation_offline
# OZZLIB += -L$(OZZLIBDIR)/src/animation/runtime -lozz_animation 
# OZZLIB += -L$(OZZLIBDIR)/src/base -lozz_base

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