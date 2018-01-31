#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include <iup.h>

#include <stdio.h>
#include <stdlib.h>

struct args {
	int argc;
	char **argv;
	Ihandle *debug;
	Ihandle *dlg;
};

int luaopen_iuplua(lua_State* L);

static int 
quit_cb(void) {
	return IUP_CLOSE;
}

static int
copy_cb(void) {
	Ihandle* clip = IupClipboard();
	Ihandle* debug = IupGetHandle("ERROR");
	char * text = IupGetAttribute(debug, "VALUE");
	IupSetAttribute(clip, "TEXT", text);

	IupDestroy(clip);
	return IUP_DEFAULT;
}

static int
esc_cb(Ihandle *self, int key) {
	if (key == K_ESC)
		return IUP_CLOSE;
	else
		return IUP_CONTINUE;
}

static void
init_iup(struct args *a) {
	IupOpen(&a->argc, &a->argv);
	Ihandle *dlg, *debug;
	debug = IupMultiLine(NULL);
	IupSetAttribute(debug, "EXPAND", "YES");
	IupSetAttribute(debug, "WORDWRAP", "YES");
	IupSetAttribute(debug, "BORDER", "YES");
	IupSetAttribute(debug, "READONLY", "YES");
	
	a->debug = debug;
	IupSetHandle("ERROR", debug);
	Ihandle * clip  = IupButton("Copy", NULL);
	IupSetCallback(clip, "ACTION", (Icallback)copy_cb);
	Ihandle * ok  = IupButton("Ok", NULL);
	IupSetCallback(ok, "ACTION", (Icallback)quit_cb);
	Ihandle *buttons = IupHbox(IupFill(), clip, IupFill(), ok, IupFill(), NULL);
	IupSetAttribute(buttons, "NORMALIZESIZE", "HORIZONTAL");
	IupSetAttribute(buttons, "MARGIN", "4x4");
	Ihandle *vbox = IupVbox(debug, buttons, NULL);
	dlg = IupDialog(vbox);
	IupSetAttribute(dlg, "TITLE", "Error");
	IupSetAttribute(dlg, "SIZE", "QUARTERxQUARTER");
	IupSetCallback(dlg, "K_ANY", (Icallback)esc_cb);
	IupSetAttributeHandle(dlg, "STARTFOCUS", ok);
	a->dlg = dlg;
	IupShow(dlg);
}

static void
l_message (struct args * a, const char *pname, const char *msg) {
	if (a->debug == NULL) {
		init_iup(a);
	}
	IupSetAttribute(a->dlg, "TITLE", pname);
	IupSetAttribute(a->debug, "VALUE", msg);
}

static int 
report (lua_State *L, int status, const char *progname, struct args *a) {
	if (status != LUA_OK) {
		const char *msg = lua_tostring(L, -1);
		l_message(a, progname, msg);
		lua_pop(L, 1);  /* remove message */
	}
	return status;
}

static int
msghandler (lua_State *L) {
	const char *msg = lua_tostring(L, 1);
	if (msg == NULL) {  /* is error object not a string? */
		if (luaL_callmeta(L, 1, "__tostring") &&  /* does it have a metamethod */
			lua_type(L, -1) == LUA_TSTRING)  /* that produces a string? */
			return 1;  /* that is the message */
		else
			msg = lua_pushfstring(L, "(error object is a %s value)",
								   luaL_typename(L, 1));
	}
	luaL_traceback(L, L, msg, 1);  /* append a standard traceback */
	return 1;  /* return the traceback */
}

int iuplua_open(lua_State * L);

static int
dummy_iuplua(lua_State *L) {
	lua_getglobal(L, "iup");
	return 1;
}

static int
pmain (lua_State *L) {
	int i;
	struct args *a = (struct args *)lua_touserdata(L, 1);
	int argc = a->argc;
	char **argv = a->argv;
	const char * filename;
	int from;
	luaL_openlibs(L);
	iuplua_open(L);
	luaL_requiref(L, "iuplua", dummy_iuplua, 0);
	lua_settop(L, 0);
	lua_pushcfunction(L, msghandler);
	if (argc < 2) {
		filename = "main.lua";
		from = 1;
	} else {
		filename = argv[1];
		from = 2;
	}
	if (luaL_loadfile(L, filename) != LUA_OK) {
		return lua_error(L);
	}
	for (i=from;i<argc;i++) {
		lua_pushstring(L, argv[i]);
	}
	if (lua_pcall(L, argc - from, 0, 1) != LUA_OK) {
		return lua_error(L);
	}
	return 0;
}

int
main (int argc, char **argv) {
	int status, result;
	struct args a = { argc, argv, NULL, NULL };
	lua_State *L = luaL_newstate();  /* create state */
	if (L == NULL) {
		l_message(&a, argv[0], "cannot create state: not enough memory");
		return EXIT_FAILURE;
	}
	lua_pushcfunction(L, &pmain);  /* to call 'pmain' in protected mode */
	lua_pushlightuserdata(L, &a); /* 2nd argument */
	status = lua_pcall(L, 1, 1, 0);  /* do the call */
	result = lua_toboolean(L, -1);  /* get result */
	report(L, status, argv[0], &a);
	lua_close(L);

	if (a.debug) {
		IupMainLoop();
		IupClose();
	}

	return (result && status == LUA_OK) ? EXIT_SUCCESS : EXIT_FAILURE;
}
