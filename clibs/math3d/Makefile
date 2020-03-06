include ../common.mk

GLM_INC = -I $(ANT3RD)/glm
CLIBS_INC = -I..
ifeq "$(PLAT)" "mingw"
default : math3d.dll
else
default : $(ODIR)/libmath3d.a
endif

math3d.dll : $(ODIR)/math3d.dll
	cp $< $@

$(ODIR)/linalg.o : linalg.c | $(ODIR)
	$(CC) -c $(CFLAGS) -o $@ $^ $(LUAINC) $(GLM_INC)

$(ODIR)/math3d.o : math3d.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -Wno-char-subscripts -o $@ $^ $(LUAINC) $(GLM_INC)

$(ODIR)/mathbaselib.o : mathbaselib.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ $(LUAINC) $(GLM_INC) $(CLIBS_INC)

$(ODIR)/util.o : util.c | $(ODIR)
	$(CC) -c $(CFLAGS) -o $@ $^ $(LUAINC) $(CLIBS_INC)

$(ODIR)/mathadapter.o : mathadapter.c | $(ODIR)
	$(CC) -c $(CFLAGS) -o $@ $^ $(LUAINC)

OBJS = $(ODIR)/linalg.o $(ODIR)/math3d.o $(ODIR)/mathbaselib.o $(ODIR)/util.o $(ODIR)/mathadapter.o

$(ODIR)/math3d.dll : $(OBJS)
	$(CC) $(LD_SHARED) $(CFLAGS) -o $@ $^ -lstdc++ $(LUALIB)

$(ODIR)/libmath3d.a : $(OBJS)
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
