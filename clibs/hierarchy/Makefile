include ../common.mk
include ozz_define.mk

GLM_DIR = -I$(ANT3RD)/glm
OZZINC = -I $(ANT3RD) -I $(ANT3RD)/ozz-animation/include	
CLIBS = -I..

ifeq "$(PLAT)" "mingw"
default : hierarchy.dll
else
default : $(ODIR)/libhierarchy.a
endif

OBJ_FILES := $(ODIR)/hierarchy.o $(ODIR)/animation.o $(ODIR)/mesh.o	$(ODIR)/ik.o

$(ODIR)/hierarchy.o: hierarchy.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $< $(LUAINC) $(GLM_DIR) $(CLIBS) $(OZZINC)

$(ODIR)/ik.o: ik.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $< $(LUAINC) $(GLM_DIR) $(CLIBS) $(OZZINC)

$(ODIR)/animation.o: animation.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $< $(LUAINC) $(GLM_DIR) $(CLIBS) $(OZZINC)

$(ODIR)/mesh.o: ozz_mesh/mesh.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $< $(LUAINC) $(GLM_DIR) $(CLIBS) $(OZZINC)

$(ODIR)/hierarchy.dll : $(OBJ_FILES)
	$(CXX) $(LD_SHARED) -lstdc++ -o $@ $^ $(LUALIB) $(GLM_DIR) $(OZZINC) $(OZZRUNTIME) $(OZZOFFLINE) $(OZZGEOMERTY) $(OZZBASE)

$(ODIR)/libhierarchy.a : $(OBJ_FILES)
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
