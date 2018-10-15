LUAINC = -I ../lua
LUALIB = -L ../lua -llua53
CFLAGS = -O2 -Wall

GLM_INC = -I ../../../ant3rd/glm

mingw : math3d.dll

math3d.dll : linalg.c math3d.cpp baselib.cpp
	gcc --shared $(CFLAGS) -o $@ $^ -lstdc++ $(LUALIB) $(LUAINC) $(GLM_INC)

clean :
	rm -f math3d.dll
