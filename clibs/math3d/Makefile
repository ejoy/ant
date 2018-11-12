include ../common.mk

GLM_INC = -I $(ANT3RD)/glm

mingw : math3d.dll

linalg.o : linalg.c
	gcc -c $(CFLAGS) -o $@ $^ -lstdc++ $(LUALIB) $(LUAINC) $(GLM_INC)

math3d.o : math3d.cpp
	gcc -c $(CFLAGS) -o $@ $^ -lstdc++ $(LUALIB) $(LUAINC) $(GLM_INC)

mathbaselib.o : mathbaselib.cpp
	gcc -c $(CFLAGS) -o $@ $^ -lstdc++ $(LUALIB) $(LUAINC) $(GLM_INC)

math3d.dll : linalg.o math3d.o mathbaselib.o
	gcc --shared $(CFLAGS) -o $@ $^ -lstdc++ $(LUALIB) $(LUAINC) $(GLM_INC)

libmath3d.a : linalg.o math3d.o mathbaselib.o
	ar rsv $@ $^

clean :
	rm -f math3d.dll
