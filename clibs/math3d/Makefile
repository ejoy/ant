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
	$(CC) -c $(CFLAGS) -o $@ $^ $(LUAINC)

$(ODIR)/math3d.o : math3d.c | $(ODIR)
	$(CC) -c $(CFLAGS) -o $@ $^ $(LUAINC)

$(ODIR)/math3dfunc.o : math3dfunc.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ $(LUAINC) $(GLM_INC) $(CLIBS_INC)

$(ODIR)/mathadapter.o : mathadapter.c | $(ODIR)
	$(CC) -c $(CFLAGS) -o $@ $^ $(LUAINC)

$(ODIR)/aabbcache.o : aabbcache.c | $(ODIR)
	$(CC) -c $(CFLAGS) -o $@ $^ $(LUAINC)

$(ODIR)/mathcache.o : mathcache.c | $(ODIR)
	$(CC) -c $(CFLAGS) -o $@ $^ $(LUAINC)

$(ODIR)/testadapter.o : testadapter.c | $(ODIR)
	$(CC) -c $(CFLAGS) -o $@ $^ $(LUAINC)

OBJS = $(ODIR)/linalg.o $(ODIR)/math3d.o $(ODIR)/math3dfunc.o \
  $(ODIR)/mathadapter.o $(ODIR)/testadapter.o \
  $(ODIR)/aabbcache.o $(ODIR)/mathcache.o

$(ODIR)/math3d.dll : $(OBJS)
	$(CC) $(LD_SHARED) $(CFLAGS) -o $@ $^ -lstdc++ $(LUALIB)

$(ODIR)/libmath3d.a : $(OBJS)
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a

test:
	../lua.exe test2.lua