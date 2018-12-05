include ../common.mk
include ../bgfx/bgfx_define.mk

ASSIMPROOT = $(ANT3RD)
ASSIMPINC = -I$(ASSIMPROOT)/assimp/include -I$(ANT3RD)/build/assimp/include
ASSIMPLIB = -L$(ASSIMPROOT)/build/assimp/code -lassimp -L$(ASSIMPROOT)/build/assimp/contrib/irrXML -lIrrXML -lz

IB_COMPRESSINC = -I$(ANT3RD)/ib-compress
IB_COMPRESSLIB = -L$(ANT3RD)/ib-compress -lib-compress

mingw : meshconverter.dll

GLM_INC := -I$(ANT3RD)/glm
$(ODIR) : 
	mkdir $@

OBGFX_DIR:=$(ODIR)/bgfx 
$(OBGFX_DIR) : | $(ODIR)
	mkdir $@

SRC_FILES := meshconverter.cpp antmesh_converter.cpp fbx_helper.cpp bgfxmesh_helper.cpp utils.cpp bgfx/util.cpp

OBJ_FILES := $(patsubst %.cpp,$(ODIR)/%.o,$(SRC_FILES))

$(OBJ_FILES) : $(ODIR)/%.o : %.cpp | $(ODIR) $(OBGFX_DIR)
	$(CXX) $(CFLAGS) -std=c++17 -c -o $@ $^ $(LUAINC) $(ASSIMPINC) $(BGFXINC) $(GLM_INC) $(IB_COMPRESSINC)
	
meshconverter.dll : $(OBJ_FILES)
	$(CXX) $(CFLAGS) -lstdc++ $(LD_SHARED) -o $@ $^ -L. $(LUALIB) $(ASSIMPLIB) $(BGFXLIB) $(IB_COMPRESSLIB)

clean :
	rm -f meshconverter.dll && rm -rf o