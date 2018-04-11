LUAINC = -I ../lua
LUALIB = -L ../lua -llua53
CFLAGS = -O2 -Wall
OZZDIR = ../ozz-animation
OZZINC = -I $(OZZDIR)/include
CXX = g++

mingw : hierarchy.dll

$(OZZDIR)/libozz.a :
	cd $(OZZDIR) && $(MAKE)

hierarchy.dll : hierarchy.cpp | $(OZZDIR)/libozz.a
	$(CXX) --shared $(CFLAGS) -o $@ $^ $(LUALIB) $(LUAINC) $(OZZINC) -L $(OZZDIR) -lozz

clean :
	rm -f hierarchy.dll
