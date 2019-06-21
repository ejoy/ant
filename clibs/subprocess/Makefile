include ../common.mk

default : subprocess.dll

OBJS = $(ODIR)/lsubprocess.o
ifeq "$(PLAT)" "mingw"
OBJS += $(ODIR)/subprocess_win.o
else ifeq "$(PLAT)" "osx"
OBJS += $(ODIR)/subprocess_posix.o
endif

subprocess.h : subprocess_win.h subprocess_posix.h 

$(ODIR)/lsubprocess.o : lsubprocess.cpp subprocess.h | $(ODIR)
	$(CXX) $(CFLAGS) -c -o $@ $< $(LUAINC)

$(ODIR)/subprocess_win.o : subprocess_win.cpp subprocess.h | $(ODIR)
	$(CXX) $(CFLAGS) -c -o $@ $<

$(ODIR)/subprocess_posix.o : subprocess_posix.cpp subprocess.h | $(ODIR)
	$(CXX) $(CFLAGS) -c -o $@ $<

subprocess.dll : $(OBJS)
	$(CC) $(CFLAGS) $(LD_SHARED) $(LUALIB) -o $@ $^ -lstdc++

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
