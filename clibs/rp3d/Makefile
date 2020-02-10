include ../common.mk
include rp3d.mk

ifeq "$(PLAT)" "mingw"
default : rp3d.dll
else
default : $(ODIR)/librp3d.a
endif

RP3D_OBJ= $(ODIR)/rp3d.o 

$(ODIR)/rp3d.o : lua-rp3d.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ $(RP3DINC) $(LUAINC)

$(ODIR)/rp3d.dll : $(RP3D_OBJ)
	$(CC) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB) $(RP3DLIB) $(RP3DINC) -lstdc++

$(ODIR)/librp3d.a : $(RP3D_OBJ)
	ar rsv $@ $^

rp3d.dll : $(ODIR)/rp3d.dll | $(ODIR)
	cp $^ $@

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(ODIR) && rm -f *.dll && rm -f $(RP3D_OBJ)

test :
	$(LUABIN) test.lua
