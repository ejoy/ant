include ../common.mk

CFLAGS = -O2 -Wall

default : registry.dll

$(ODIR)/unicode.o : bee/utility/unicode_win.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $< -I. -DBEE_INLINE

$(ODIR)/lua_registry.o : lua_registry.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $< -I. $(LUAINC) -DBEE_INLINE -DBEE_STATIC -D'lua_newuserdatauv(a,b,c)=lua_newuserdata(a,b)'

$(ODIR)/lregistry.o : lregistry.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $<

registry.dll : $(ODIR)/lregistry.o $(ODIR)/lua_registry.o $(ODIR)/unicode.o
	$(CXX) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB)

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
