include ../common.mk
include bullet.mk

ifeq "$(PLAT)" "mingw"
default : bullet.dll
else
default : $(ODIR)/libbullet.a
endif

BULLET_OBJ= $(ODIR)/bullet.o 

$(ODIR)/bullet.o : bullet.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ $(BULLETINC) $(LUAINC)

$(ODIR)/bullet.dll : $(BULLET_OBJ)
	$(CC) $(LD_SHARED) $(CFLAGS) -o $@ $^ -lstdc++ $(LUALIB) $(BULLETLIB) $(BULLETINC)

$(ODIR)/libbullet.a : $(BULLET_OBJ)
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(ODIR) && rm -f *.dll && rm -f $(BULLET_OBJ)
