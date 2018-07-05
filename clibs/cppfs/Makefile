LUAINC = -I ../lua
LUALIB = -L ../lua -llua53 -lstdc++fs
CFLAGS = -O2 -Wall

mingw : cppfs.dll

cppfs.dll : cppfs.cpp
	g++ --shared $(CFLAGS) $(LUAINC) -o $@ $^ $(LUALIB)

clean :
	rm -f cppfs.dll
