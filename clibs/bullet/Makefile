include ../common.mk
include bullet.mk

ifeq "$(PLAT)" "mingw"
default : bullet.dll
else
default : libbullet-$(PLAT).a
endif

BULLET_OBJ= $(ODIR)/bullet.o 

$(ODIR)/bullet.o : bullet.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) $(CXXFLAGS) -o $@ $^ $(BULLETINC) $(LUAINC)

bullet.dll : $(BULLET_OBJ)
	$(CXX) $(LD_SHARED) $(CFLAGS) $(CXXFLAGS) -o $@ $^ -lstdc++ $(LUALIB) $(BULLETLIB) $(BULLETINC)

libbullet-$(PLAT).a : $(BULLET_OBJ)
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(ODIR) && rm -f *.dll && rm -f $(BULLET_OBJ)
