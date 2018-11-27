include ../common.mk
include ../bgfx/bgfx_define.mk

ASSIMPROOT = $(ANT3RD)
ASSIMPINC = -I$(ASSIMPROOT)/assimp/include -I$(ANT3RD)/build/assimp/include
ASSIMPLIB = -L$(ASSIMPROOT)/build/assimp/code -lassimp -L$(ASSIMPROOT)/build/assimp/contrib/irrXML -lIrrXML -lz

mingw : meshconverter.dll

GLM_INC := -I$(ANT3RD)/glm
$(ODIR) : 
	mkdir $@

OBGFX_DIR:=$(ODIR)/bgfx 
$(OBGFX_DIR): $(ODIR)
	mkdir $@

OBGFX_IB_COMPRESS_DIR:=$(ODIR)/bgfx/ib-compress
$(OBGFX_IB_COMPRESS_DIR): | $(OBGFX_DIR)
	mkdir $@

SRC_FILES := meshconverter.cpp antmesh_converter.cpp fbx_helper.cpp bgfxmesh_helper.cpp utils.cpp \
			bgfx/util.cpp bgfx/ib-compress/indexbufferdecompression.cpp
OBJ_FILES := $(patsubst %.cpp,$(ODIR)/%.o,$(SRC_FILES))

$(OBJ_FILES) : $(ODIR)/%.o : %.cpp | $(ODIR) $(OBGFX_DIR) $(OBGFX_IB_COMPRESS_DIR)
	$(CXX) $(CFLAGS) $(CXXFLAGS) -c -o $@ $^ -L. $(LUAINC) $(ASSIMPINC) $(BGFXINC) $(GLM_INC)
	
meshconverter.dll : $(OBJ_FILES)
	#$(CXX) $(CFLAGS) $(CXXFLAGS) --shared -o $@ $^ -L. $(LUALIB) $(ASSIMPLIB) $(BGFXUTILLIB) $(BGFXLIB) $(BIMG_DECODELIB)
	$(CXX) $(CFLAGS) $(CXXFLAGS) --shared -o $@ $^ -L. $(LUALIB) $(ASSIMPLIB) $(BGFXLIB) $(BIMG_DECODELIB)

clean :
	rm -f meshconverter.dll && rm -rf o