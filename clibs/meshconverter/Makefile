include ../common.mk
include ../bgfx/bgfx_define.mk

CLIBSINC = -I..

ifeq "$(PLAT)" "mingw"
default : meshconverter.dll
else
default : libmeshconverter-$(PLAT).a
endif

GLM_INC := -I$(ANT3RD)/glm
$(ODIR) : 
	mkdir -p $@

SRC_FILES := utils.cpp gltf_converter.cpp
OBJ_FILES := $(patsubst %.cpp,$(ODIR)/%.o,$(SRC_FILES))

$(OBJ_FILES) : $(ODIR)/%.o : %.cpp | $(ODIR)
	$(CXX) $(CFLAGS) -std=c++17 -c -o $@ $^ $(LUAINC) $(GLM_INC) $(CLIBSINC)
	
meshconverter.dll : $(OBJ_FILES)
	$(CXX) $(CFLAGS) -lstdc++ $(LD_SHARED) -o $@ $^ -L. $(LUALIB)

libmeshconverter-$(PLAT).a : $(OBJ_FILES)
	ar rsv $@ $^

clean :
	rm -f meshconverter.dll && rm -rf o
