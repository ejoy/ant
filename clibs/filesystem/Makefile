include ../common.mk

ifeq "$(PLAT)" "mingw"
default : filesystem.dll
else
default : $(ODIR)/libfilesystem.a
endif

OBJS = $(ODIR)/lua_filesystem.o $(ODIR)/path_helper.o $(ODIR)/file_helper.o  $(ODIR)/error.o

ifeq "$(PLAT)" "mingw"
LIBS = -lstdc++fs
OBJS += $(ODIR)/unicode.o $(ODIR)/windows_category.o
endif

$(ODIR)/windows_category.o : windows_category.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

$(ODIR)/error.o : error.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

$(ODIR)/unicode.o : unicode.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

$(ODIR)/path_helper.o : path_helper.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

$(ODIR)/file_helper.o : file_helper.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

$(ODIR)/lua_filesystem.o : lua_filesystem.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

$(ODIR)/filesystem.dll : $(OBJS)
	$(CXX) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB) $(LIBS)

$(ODIR)/libfilesystem.a : $(OBJS)
	ar rsv $@ $^

filesystem.dll : $(ODIR)/filesystem.dll
	cp $^ $@

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
