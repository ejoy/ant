LUAINC = -I./lua53/src
LUALIB = -L./lua53/src -llua
CFLAGS = -O2 -Wall -std=c++17 -fPIC

all : subprocess.so

subprocess.so : binding.cpp posix/subprocess.cpp
	g++ --shared $(CFLAGS) $(LUAINC) -o $@ $^ $(LUALIB)

clean :
	rm -f subprocess.so
