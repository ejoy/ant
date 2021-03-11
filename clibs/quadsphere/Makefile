include ../common.mk

CLIBS_INC = -I..
ifeq "$(PLAT)" "mingw"
default : quadsphere.dll
else
default : $(ODIR)/libquad_sphere.a
endif

quadsphere.dll : $(ODIR)/quadsphere.dll
	cp $< $@

$(ODIR)/quadsphere.o : quadsphere.cpp | $(ODIR)
	$(CC) -c $(CFLAGS) -o $@ $^ $(LUAINC)

$(ODIR)/cubesphere.o : cubesphere.c | $(ODIR)
	$(CC) -c $(CFLAGS) -o $@ $^

OBJS = $(ODIR)/quadsphere.o $(ODIR)/cubesphere.o

$(ODIR)/quadsphere.dll : $(OBJS)
	$(CC) $(LD_SHARED) $(CFLAGS) -o $@ $^ -lstdc++ $(LUALIB)

$(ODIR)/libquad_sphere.a : $(OBJS)
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a