include ../common.mk

GLM_INC = -I $(ANT3RD)/glm

ifeq "$(PLAT)" "mingw"
default : meshbase.dll
else
default : libmeshbase-$(PLAT).a
endif

$(ODIR)/meshbase.o : meshbase.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ $(LUAINC) $(GLM_INC)

meshbase.dll : $(ODIR)/meshbase.o
	$(CXX) $(LD_SHARED) $(CFLAGS) -o $@ $^ -lstdc++

libmath3d-$(PLAT).a : $(ODIR)/meshbase.o 
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(ODIR) *.dll *.a