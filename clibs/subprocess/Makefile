include ../common.mk

default : subprocess.dll

OBJS = $(ODIR)/lsubprocess.o $(ODIR)/file_helper.o 
ifeq "$(PLAT)" "mingw"
OBJS += $(ODIR)/subprocess_win.o
LIBS = -lstdc++ -lole32
else ifeq "$(PLAT)" "osx"
OBJS += $(ODIR)/subprocess_posix.o
LIBS = -lstdc++
endif

subprocess.h : subprocess_win.h subprocess_posix.h 

$(ODIR)/lsubprocess.o : lsubprocess.cpp subprocess.h | $(ODIR)
	$(CXX) $(CFLAGS) -c -o $@ $< $(LUAINC)

$(ODIR)/file_helper.o : file_helper.cpp file_helper.h | $(ODIR)
	$(CXX) $(CFLAGS) -c -o $@ $< $(LUAINC)

$(ODIR)/subprocess_win.o : subprocess_win.cpp subprocess.h | $(ODIR)
	$(CXX) $(CFLAGS) -c -o $@ $<

$(ODIR)/subprocess_posix.o : subprocess_posix.cpp subprocess.h | $(ODIR)
	$(CXX) $(CFLAGS) -c -o $@ $<

$(ODIR)/subprocess.dll : $(OBJS)
	$(CC) $(CFLAGS) $(LD_SHARED) $(LUALIB) -o $@ $^ $(LIBS)

subprocess.dll: $(ODIR)/subprocess.dll | $(ODIR)
	cp $^ $@

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
