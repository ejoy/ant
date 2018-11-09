#include "winfile.h"
#include "luavm.h"
#include "config.h"
#include <stdio.h>
#include <windows.h>

// project path in my documents
#define ANTCLIENT "antclient"
#define CLASSNAME L"ANTCLIENT"
#define WINDOWSTYLE (WS_OVERLAPPEDWINDOW & ~WS_THICKFRAME & ~WS_MAXIMIZEBOX)

#define CR "\n"

static const char * config_default = 
	"width, height = 1024, 768" CR
	"title = 'Ant client'" CR
	"bootstrap = 'main.lua'";

static const char * lua_init =
	"local log, bootstrap, wnd, width, height = ..." CR
	"local f = assert(loadfile(bootstrap))" CR
	"_HANDLE = f { window = wnd, log = log, width = width, height = height }";

static const char * lua_update =
	"local update = assert(_HANDLE.update)" CR
	"return update";

static const char * lua_message =
	"local message = assert(_HANDLE.message)" CR
	"return message";

struct vm {
	struct luavm *V;
	struct ant_client_config *config;
	int message;
	int update;
};

static int
mkdir(const char *path) {
	int t = wfile_type(path);
	switch(t) {
	case WFILE_NONE:
		return wfile_mkdir(path);
	case WFILE_DIR:
		return 1;
	default:
		return 0;
	}
}

static int
create_cache(const char *path) {
	if (!mkdir(path))
		return 0;
	char tmp[MAX_PATH] = { 0 };
	wfile_concat(tmp, MAX_PATH, path);
	if (!wfile_concat(tmp, MAX_PATH, ".repo"))
		return 0;
	// mkdir path/.repo
	if (!mkdir(tmp))
		return 0;
	int sz = wfile_concat(tmp, MAX_PATH, "00");
	if (sz == 0)
		return 0;
	int i;
	for (i=0;i<=0xff;i++) {
		sprintf(tmp + sz - 2, "%02x", i);
		if (!mkdir(tmp)) {
			return 0;
		}
	}

	return 1;
}

static int
loadconfig(const char * projpath, struct ant_client_config *c) {
	char path[MAX_PATH];
	if (!wfile_personaldir(path, MAX_PATH)) {
		printf("Get personaldir failed\n");
		return 1;
	}

	if (!wfile_concat(path, MAX_PATH, projpath)) {
		printf("Invalid path %s\n", projpath);
		return 1;
	}

	if (!create_cache(path)) {
		printf("Can't init cache\n");
		return 1;
	}

	if (!wfile_concat(path, MAX_PATH, "config.txt"))
		return 1;

	if (wfile_type(path) == WFILE_NONE) {
		FILE *f = wfile_open(path, "wb");
		fprintf(f, "%s",config_default);
		fclose(f);
	}

	if (!antclient_loadconfig(path, c)) {
		printf("Load config failed\n");
		return 1;
	}

	return 0;
}

static void
get_xy(LPARAM lParam, int *x, int *y) {
	*x = (short)(lParam & 0xffff); 
	*y = (short)((lParam>>16) & 0xffff); 
}

static void
create_vm(struct vm *vm, HWND wnd) {
	struct luavm *V = luavm_new();
	const char * err = luavm_init(V, lua_init, "spii", vm->config->bootstrap, wnd, vm->config->width, vm->config->height);
	if (err) goto _err;
	err = luavm_register(V, lua_update, "=update", &vm->update);
	if (err) goto _err;
	err = luavm_register(V, lua_message, "=message", &vm->message);
	if (err) goto _err;
	vm->V = V;
	return;
_err:
	printf("Error: %s\n", err);
	luavm_close(V);
	PostQuitMessage(0);
}

static void
close_vm(struct vm *vm) {
	luavm_close(vm->V);
	vm->V = NULL;
}

static void
update_vm(struct vm *vm) {
	const char *err = luavm_call(vm->V, vm->update, "");
	if (err) {
		printf("Update Error: %s\n", err);
	}
}

static void
message_vm(struct vm *vm, const char * message, int x, int y) {
	const char *err = luavm_call(vm->V, vm->message, "sii", message, x, y);
	if (err) {
		printf("Message Error: %s\n", err);
	}
}

static LRESULT CALLBACK
WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam)
{
	struct vm *vm = NULL;
	switch (message) {
	case WM_CREATE: {
		LPCREATESTRUCTA cs = (LPCREATESTRUCTA)lParam;
		vm = (struct vm *)cs->lpCreateParams;
		create_vm(vm, hWnd);
		SetWindowLongPtr(hWnd, GWLP_USERDATA, (LONG_PTR)vm);
		break;
	}
//	case WM_PAINT: {
//		if (GetUpdateRect(hWnd, NULL, FALSE)) {
//			vm = (struct vm *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
//			update_vm(vm);
//			ValidateRect(hWnd, NULL);
//		}
//		return 0;
//	}
	case WM_DESTROY:
		vm = (struct vm *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		close_vm(vm);		
		PostQuitMessage(0);
		return 0;
	case WM_LBUTTONUP:
	case WM_LBUTTONDOWN:
	case WM_MOUSEMOVE: {
		int x,y;
		get_xy(lParam, &x, &y); 
		vm = (struct vm *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		const char * msg = NULL;
		switch(message) {
		case WM_LBUTTONUP: msg = "lbu"; break;
		case WM_LBUTTONDOWN: msg = "lbd"; break;
		case WM_MOUSEMOVE: msg = "move"; break;
		default: msg = "unknown"; break;
		}
		message_vm(vm, msg, x, y);
		break;
	}
	}
	return DefWindowProcW(hWnd, message, wParam, lParam);
}

static void
register_class()
{
	WNDCLASSW wndclass;

	wndclass.style = CS_HREDRAW | CS_VREDRAW | CS_OWNDC;
	wndclass.lpfnWndProc = WndProc;
	wndclass.cbClsExtra = 0;
	wndclass.cbWndExtra = 0;
	wndclass.hInstance = GetModuleHandleW(0);
	wndclass.hIcon = 0;
	wndclass.hCursor = 0;
	wndclass.hbrBackground = 0;
	wndclass.lpszMenuName = 0; 
	wndclass.lpszClassName = CLASSNAME;

	RegisterClassW(&wndclass);
}

static HWND
create_window(const char * name, int w, int h, void * ud) {
	RECT rect;

	rect.left=0;
	rect.right=w;
	rect.top=0;
	rect.bottom=h;

	AdjustWindowRect(&rect,WINDOWSTYLE,0);

	wchar_t wndname[MAX_PATH];

	int wsz = MultiByteToWideChar(CP_UTF8, 0, name, strlen(name), wndname, MAX_PATH);
	if (wsz == 0)
		return NULL;
	wndname[wsz] = 0;

	HWND wnd=CreateWindowExW(0,CLASSNAME,wndname,
		WINDOWSTYLE, CW_USEDEFAULT,0,
		rect.right-rect.left,rect.bottom-rect.top,
		0,0,
		GetModuleHandleW(0),
		ud);

	return wnd;
}

int
main(int argc, char *argv[]) {
	const char * projpath = ANTCLIENT;
	if (argc == 2) {
		projpath = argv[1];
	}
	struct ant_client_config c;
	if(loadconfig(projpath, &c)) {
		return 1;
	}

	register_class();
	struct vm vm;
	vm.V = NULL;
	vm.config = &c;
	HWND wnd = create_window(c.title, c.width, c.height, &vm);

	ShowWindow(wnd, SW_SHOWDEFAULT);
	UpdateWindow(wnd);

	MSG msg;
/*
	while (GetMessage(&msg, NULL, 0, 0)) {
		TranslateMessage(&msg);
		DispatchMessage(&msg);
	}
*/

	for (;;) {
		if (PeekMessage (&msg, NULL, 0, 0, PM_REMOVE)) {
			if (msg.message == WM_QUIT)
				break;
			TranslateMessage(&msg); 
			DispatchMessage(&msg); 
		} else {
			update_vm(&vm);
			Sleep(0);
		}
	}

	return 0;
}
