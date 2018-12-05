include ../common.mk

GLM_INC = -I $(ANT3RD)/glm

ifeq "$(PLAT)" "mingw"
default : math3d.dll
else
default : libmath3d.a
endif

linalg.o : linalg.c
	$(CC) -c $(CFLAGS) -o $@ $^ $(LUAINC) $(GLM_INC)

math3d.o : math3d.cpp
	$(CXX) -c $(CFLAGS) -o $@ $^ $(LUAINC) $(GLM_INC) -Wchar-subscripts

mathbaselib.o : mathbaselib.cpp
	$(CXX) -c $(CFLAGS) -o $@ $^ $(LUAINC) $(GLM_INC)

math3d.dll : linalg.o math3d.o mathbaselib.o
	$(CXX) $(LD_SHARED) $(CFLAGS) -o $@ $^ -lstdc++ $(LUALIB)

libmath3d.a : linalg.o math3d.o mathbaselib.o
	ar rsv $@ $^

clean :
	rm -f math3d.dll libmath3d.a *.o
