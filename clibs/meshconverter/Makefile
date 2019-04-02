include ../common.mk
include ../bgfx/bgfx_define.mk

ASSIMPROOT = $(ANT3RD)
ASSIMPINC = -I$(ASSIMPROOT)/assimp/include -I$(ANT3RD)/build/assimp/$(PLAT)/include
ASSIMPLIB = -L$(ASSIMPROOT)/build/assimp/$(PLAT)/code -lassimp -L$(ASSIMPROOT)/build/assimp/$(PLAT)/contrib/irrXML -lIrrXML -lz

IB_COMPRESSINC = -I$(ANT3RD)/ib-compress
IB_COMPRESSLIB = -L$(ANT3RD)/ib-compress -lib-compress-$(PLAT)

CLIBSINC = -I..

default : meshconverter.dll

GLM_INC := -I$(ANT3RD)/glm
$(ODIR) : 
	mkdir -p $@

OBGFX_DIR:=$(ODIR)/bgfx 
$(OBGFX_DIR) : | $(ODIR)
	mkdir -p $@

SRC_FILES := meshconverter.cpp antmesh_converter.cpp fbx_helper.cpp bgfxmesh_helper.cpp utils.cpp bgfx/util.cpp

OBJ_FILES := $(patsubst %.cpp,$(ODIR)/%.o,$(SRC_FILES))

$(OBJ_FILES) : $(ODIR)/%.o : %.cpp | $(ODIR) $(OBGFX_DIR)
	$(CXX) $(CFLAGS) -std=c++17 -c -o $@ $^ $(LUAINC) $(ASSIMPINC) $(BGFXINC) $(GLM_INC) $(IB_COMPRESSINC) $(CLIBSINC)
	
meshconverter.dll : $(OBJ_FILES)
	$(CXX) $(CFLAGS) -lstdc++ $(LD_SHARED) -o $@ $^ -L. $(LUALIB) $(ASSIMPLIB) $(BGFXLIB) $(IB_COMPRESSLIB)

clean :
	rm -f meshconverter.dll && rm -rf o
