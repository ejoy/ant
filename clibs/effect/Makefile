include ../common.mk
include ../bgfx/bgfx_define.mk

CLIBS_INC = -I..
GLM_INC = -I$(ANT3RD)/glm
ifeq "$(PLAT)" "mingw"
default : effect.dll
else
default : $(ODIR)/effect.a
endif

effect.dll : $(ODIR)/effect.dll
	cp $< $@

SRC_FILES := attributes.cpp effect.cpp emitter.cpp particle_mgr.cpp particle.cpp quadcache.cpp

OBJ_FILES := $(addsuffix .o, $(basename $(SRC_FILES)))
OBJS := $(addprefix $(ODIR)/, $(OBJ_FILES))

$(ODIR)/%.o : %.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ $(LUAINC) $(GLM_INC) $(BGFXINC) $(CLIBS_INC)

$(ODIR)/effect.dll : $(OBJS)
	$(CXX) $(LD_SHARED) $(CFLAGS) $(CPPFLAGS) -o $@ $^ -lstdc++ -L$(BGFXLIBDIR) $(BIMGDECODELIB)  $(BIMGLIB) $(BXLIB) $(LUALIB)

$(ODIR)/libeffect.a : $(OBJS)
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a