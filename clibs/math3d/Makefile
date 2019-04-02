include ../common.mk

GLM_INC = -I $(ANT3RD)/glm
CLIBS_INC = -I..
ifeq "$(PLAT)" "mingw"
default : math3d.dll
else
default : libmath3d-$(PLAT).a
endif

$(ODIR)/linalg.o : linalg.c | $(ODIR)
	$(CC) -c $(CFLAGS) -o $@ $^ $(LUAINC) $(GLM_INC)

$(ODIR)/math3d.o : math3d.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -Wno-char-subscripts -o $@ $^ $(LUAINC) $(GLM_INC)

$(ODIR)/mathbaselib.o : mathbaselib.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ $(LUAINC) $(GLM_INC) $(CLIBS_INC)

$(ODIR)/mathadapter.o : mathadapter.c | $(ODIR)
	$(CC) -c $(CFLAGS) -o $@ $^ $(LUAINC)

math3d.dll : $(ODIR)/linalg.o $(ODIR)/math3d.o $(ODIR)/mathbaselib.o $(ODIR)/mathadapter.o
	$(CXX) $(LD_SHARED) $(CFLAGS) -o $@ $^ -lstdc++ $(LUALIB)

libmath3d-$(PLAT).a : $(ODIR)/linalg.o $(ODIR)/math3d.o $(ODIR)/mathbaselib.o $(ODIR)/mathadapter.o
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(ODIR) *.dll *.a
