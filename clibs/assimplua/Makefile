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

BUILD_CFG = Release
BGFXLIB = -L$(BGFXSRC)/.build/win64_mingw-gcc/bin -lbgfx$(BUILD_CFG) -lbimg$(BUILD_CFG) -lbimg_decode$(BUILD_CFG) -lbx$(BUILD_CFG) -lstdc++ -lgdi32 -lpsapi -luuid \
-lbgfx-shared-lib$(BUILD_CFG)
BGFXUTILLIB = -lexample-common$(BUILD_CFG)

BXLIB = -lbx$(BUILD_CFG)
#BGFX3RDINC = -I$(BGFXSRC)/3rdparty
BGFXINC = -I$(BGFXSRC)/include -I$(BXSRC)/include -I$(BXSRC)/include/compat/mingw -I$(BGFXSRC)/src -I$(BGFXSRC)/examples/common -I$(BIMG)/include
GLM_INC := -I$(ANT3RD)/glm
$(ODIR) : 
	mkdir $@

#$(CD_LUAOBJS) : $(OCDDIR)/%.o : $(CD_DIR)/src/lua5/%.c | $(OCDDIR)
#$(ODIR)/luaassimplua.o : assimplua.cpp fbxhelper.cpp  | $(ODIR)

SRC_FILES := assimplua.cpp antmesh_converter.cpp fbx_helper.cpp bgfxmesh_helper.cpp utils.cpp
OBJ_FILES := $(patsubst %.cpp,$(ODIR)/%.o,$(SRC_FILES))

$(OBJ_FILES) : $(ODIR)/%.o : %.cpp | $(ODIR)
	$(CXX) $(CFLAGS) $(CXXFLAGS) -c -o $@ $^ -L. $(LUAINC) $(ASSIMPINC) $(BGFXINC) $(GLM_INC)
	
assimplua.dll : $(OBJ_FILES)
	$(CXX) $(CFLAGS) $(CXXFLAGS) --shared -o $@ $^ -L. $(LUALIB) $(ASSIMPLIB) $(BGFXUTILLIB) $(BGFXLIB) $(BXLIB)

clean :
	rm -f assimplua.dll