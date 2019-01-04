include ../common.mk

default :  filesystem.dll

ifeq "$(PLAT)" "mingw"
LIBS = -lstdc++fs
OBJS = $(ODIR)/lua_filesystem.o $(ODIR)/path_helper.o $(ODIR)/unicode.o $(ODIR)/windows_category.o $(ODIR)/error.o $(ODIR)/file_helper.o
else
OBJS = $(ODIR)/lua_posixfs.o
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

$(ODIR)/lua_posixfs.o : lua_posixfs.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

filesystem.dll : $(OBJS)
	$(CXX) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB) $(LIBS)

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
