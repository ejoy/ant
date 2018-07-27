LUAINC = -I ../lua
LUALIB = -L ../lua -llua53
CFLAGS = -O2 -Wall

mingw : math3d.dll

SRC_FILES = linalg.c math3d.cpp matrix44.c conversion.c


math3d.dll : linalg.c math3d.cpp matrix44.c conversion.c
	gcc --shared $(CFLAGS) -o $@ $^ $(LUALIB) $(LUAINC)

clean :
	rm -f math3d.dll
