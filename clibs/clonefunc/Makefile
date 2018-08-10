LUA_INC ?= -I../lua
LUA_LIB ?= -L../lua -llua

mingw : clonefunc.dll

clonefunc.dll : clonefunc.c
	gcc -g -o $@ --shared $^ $(LUA_INC) $(LUA_LIB)

clean:
	rm -f clonefunc.dll	
