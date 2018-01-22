LUAINC = -I ../lua
LUALIB = -L ../lua -llua53

math3d.dll : linalg.c math3d.c
	gcc --shared -g -Wall -o $@ $^ $(LUALIB) $(LUAINC)

clean :
	rm math3d.dll
