include ../common.mk
include ozz_define.mk

GLM_DIR = -I$(ANT3RD)/glm
OZZINC = -I $(ANT3RD) -I $(ANT3RD)/ozz-animation/include	
CLIBS = -I..

OZZ_SAMPLE_DIR=$(ANT3RD)/ozz-animation/samples

ifeq "$(PLAT)" "mingw"
default : hierarchy.dll
DECLSPEC=
else
default : $(ODIR)/libhierarchy.a
DECLSPEC= -fdeclspec
endif

OBJ_FILES := $(ODIR)/hierarchy.o $(ODIR)/animation.o $(ODIR)/mesh.o $(ODIR)/ik.o $(ODIR)/ozzmesh.o $(ODIR)/scene.o

$(ODIR)/scene.o : scene.c | $(ODIR)
	$(CC) -c $(CFLAGS) -o $@ $< $(LUAINC)

$(ODIR)/hierarchy.o: hierarchy.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $< $(LUAINC) $(GLM_DIR) $(CLIBS) $(OZZINC)

$(ODIR)/ik.o: ik.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $< $(LUAINC) $(GLM_DIR) $(CLIBS) $(OZZINC)

$(ODIR)/animation.o: animation.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) $(DECLSPEC) -o $@ $< $(LUAINC) $(GLM_DIR) $(CLIBS) $(OZZINC)

$(ODIR)/ozzmesh.o: ozzmesh.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $< $(LUAINC) $(GLM_DIR) $(CLIBS) $(OZZINC)

$(ODIR)/mesh.o: $(OZZ_SAMPLE_DIR)/framework/mesh.cc | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $< $(LUAINC) $(GLM_DIR) $(CLIBS) $(OZZINC) $(OZZ_SAMPLE_DIR)/framework

$(ODIR)/hierarchy.dll : $(OBJ_FILES)
	$(CXX) $(LD_SHARED) -lstdc++ -o $@ $^ $(LUALIB) $(GLM_DIR) $(OZZINC) $(OZZRUNTIME) $(OZZOFFLINE) $(OZZGEOMERTY) $(OZZBASE)

$(ODIR)/libhierarchy.a : $(OBJ_FILES)
	ar rsv $@ $^

hierarchy.dll : $(ODIR)/hierarchy.dll
	cp $^ $@

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
