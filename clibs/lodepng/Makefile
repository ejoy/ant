LUAINC = -I ../lua
LUALIB = -L ../lua -llua53
LODEPNGINC = -I ./


CFLAGS = -O2 -Wall
CXX = g++

mingw : lodepnglua.dll
lodepng.o : lodepng.cpp
	$(CXX) $(CFLAGS) -c -o $@ $^ -L.

lodepnglua.o : lodepnglua.cpp 
	$(CXX) $(CFLAGS) -c -o $@ $^ -L. $(LUAINC) $(LODEPNGINC)

lodepnglua.dll : lodepnglua.o lodepng.o
	$(CXX) $(CFLAGS) --shared -o $@ $^ -L. $(LUALIB)
	cp -R lodepnglua.dll ../../bin 

clean:
	rm -f lodepnglua.dll
