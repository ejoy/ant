include ../common.mk

ifeq "$(PLAT)" "mingw"
default : lsocket.dll
else
default : liblsocket-$(PLAT).a
endif

ifeq "$(PLAT)" "mingw"
OBJS = $(ODIR)/lsocket.o $(ODIR)/win_compat.o
else
OBJS = $(ODIR)/lsocket.o
endif

$(ODIR)/lsocket.o : lsocket.c win_compat.h | $(ODIR)
	$(CC) -c $(CFLAGS) $(LUAINC) -o $@ $<

$(ODIR)/win_compat.o : win_compat.c win_compat.h | $(ODIR)
	$(CC) -c $(CFLAGS) $(LUAINC) -o $@ $<

lsocket.dll : $(OBJS)
	$(CXX) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB) -lws2_32

liblsocket-$(PLAT).a : $(OBJS)
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
