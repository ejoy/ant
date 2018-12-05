include ../common.mk

ifeq "$(PLAT)" "mingw"
default : lsocket.dll
else
default : liblsocket.a
endif

ifeq "$(PLAT)" "mingw"
OBJS = lsocket.o win_compat.o
else
OBJS = lsocket.o
endif

lsocket.o : lsocket.c win_compat.h
	$(CC) -c $(CFLAGS) $(LUAINC) -o $@ $<

win_compat.o : win_compat.c win_compat.h
	$(CC) -c $(CFLAGS) $(LUAINC) -o $@ $<

lsocket.dll : $(OBJS)
	$(CXX) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB) -lws2_32

liblsocket.a : $(OBJS)
	ar rsv $@ $^

clean:
	rm -f *.o *.so *.dll *.a
