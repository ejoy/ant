ANT3RD = ../../../ant3rd
ASSIMPROOT = $(ANT3RD)
BGFXROOT = $(ANT3RD)
LUAINC = -I../lua
LUALIB = -L../lua -llua53
ASSIMPINC = -I$(ASSIMPROOT)/assimp/include -I$(ANT3RD)/build/assimp/include
ASSIMPLIB = -L$(ASSIMPROOT)/build/assimp/code -lassimp -L$(ASSIMPROOT)/build/assimp/contrib/irrXML -lIrrXML -lz

BGFXSRC = $(BGFXROOT)/bgfx
BXSRC = $(BGFXROOT)/bx


CFLAGS = -O2 -Wall -lstdc++ -std=c++17
ODIR = o
CXX = g++

mingw : assimplua.dll

BUILD_CFG = Release
BGFXLIB = -L$(BGFXSRC)/.build/win64_mingw-gcc/bin -lbgfx$(BUILD_CFG) -lbimg$(BUILD_CFG) -lbimg_decode$(BUILD_CFG) -lbx$(BUILD_CFG) -lstdc++ -lgdi32 -lpsapi -luuid \
-lbgfx-shared-lib$(BUILD_CFG)
BGFXUTILLIB = -lexample-common$(BUILD_CFG)

BXLIB = -lbx$(BUILD_CFG)
#BGFX3RDINC = -I$(BGFXSRC)/3rdparty
BGFXINC = -I$(BGFXSRC)/include -I$(BXSRC)/include -I$(BXSRC)/include/compat/mingw -I$(BGFXSRC)/src -I$(BGFXSRC)/examples/common
GLM_INC := -I$(ANT3RD)/glm
$(ODIR) : 
	mkdir $@

#$(CD_LUAOBJS) : $(OCDDIR)/%.o : $(CD_DIR)/src/lua5/%.c | $(OCDDIR)
#$(ODIR)/luaassimplua.o : assimplua.cpp fbxhelper.cpp  | $(ODIR)

SRC_FILES := assimplua.cpp fbxhelper.cpp 
OBJ_FILES := $(patsubst %.cpp,$(ODIR)/%.o,$(SRC_FILES))

$(OBJ_FILES) : $(ODIR)/%.o : %.cpp | $(ODIR)
	$(CXX) $(CFLAGS) -c -o $@ $^ -L. $(LUAINC) $(ASSIMPINC) $(BGFXINC) $(GLM_INC)
	
assimplua.dll : $(OBJ_FILES)
	$(CXX) $(CFLAGS) --shared -o $@ $^ -L. $(LUALIB) $(ASSIMPLIB) $(BGFXLIB) $(BGFXUTILLIB) $(BXLIB)

clean :
	rm -f assimplua.dll