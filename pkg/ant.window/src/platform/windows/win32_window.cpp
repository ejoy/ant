#include <Windows.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <vector>
#include <memory>
#include <bee/win/wtf8.h>
#include <bee/nonstd/unreachable.h>
#include "../../window.h"

#define CLASSNAME L"ANTCLIENT"

struct DropManager : public IDropTarget {
	ULONG m_refcount = 0;
	ULONG AddRef() { return InterlockedIncrement(&m_refcount); }
	ULONG Release() { return InterlockedDecrement(&m_refcount); }
	HRESULT QueryInterface(REFIID iid, void** ppv) {
		if (IsEqualIID(iid, IID_IUnknown) || IsEqualIID(iid, IID_IDropTarget)) {
			*ppv = static_cast<IDropTarget*>(this);
			AddRef();
			return S_OK;
		}
		*ppv = NULL;
		return E_NOINTERFACE;
	}
	//---------------------------------------------
	//---------------------------------------------
	std::vector<std::string> m_files;
	lua_State* m_L = NULL;
	HWND m_window = NULL;

	HRESULT DragEnter(IDataObject* pDataObj, DWORD grfKeyState, POINTL pt, DWORD* pdwEffect) {
		FORMATETC fmte = { CF_HDROP, NULL, DVASPECT_CONTENT, -1, TYMED_HGLOBAL };
		STGMEDIUM stgm;
		if (SUCCEEDED(pDataObj->GetData(&fmte, &stgm))) {
			HDROP hdrop = reinterpret_cast<HDROP>(stgm.hGlobal);
			UINT n = DragQueryFileW(hdrop, 0xFFFFFFFF, NULL, 0);
			for (UINT i = 0; i < n; i++) {
				UINT wlen = ::DragQueryFileW(hdrop, i, NULL, 0);
				wlen++;
				std::unique_ptr<wchar_t[]> wstr(new wchar_t[wlen]);
				::DragQueryFileW(hdrop, i, wstr.get(), wlen);
				m_files.push_back(bee::wtf8::w2u({ wstr.get(), (size_t)(wlen-1) }));
			}
			ReleaseStgMedium(&stgm);
		}
		*pdwEffect &= DROPEFFECT_COPY;
		return S_OK;
	}
	HRESULT DragLeave() {
		m_files.clear();
		return S_OK;
	}
	HRESULT DragOver(DWORD grfKeyState, POINTL pt, DWORD* pdwEffect) {
		*pdwEffect &= DROPEFFECT_COPY;
		return S_OK;
	}
	HRESULT Drop(IDataObject* pDataObj, DWORD grfKeyState, POINTL pt, DWORD* pdwEffect) {
		window_message_dropfiles(m_L, m_files);
		m_files.clear();
		*pdwEffect &= DROPEFFECT_COPY;
		return S_OK;
	}
	void Register(HWND window, lua_State* L) {
		m_window = window;
		m_L = L;
		RegisterDragDrop(m_window, this);
	}
	void Revoke() {
		RevokeDragDrop(m_window);
	}
};

struct WindowData {
	HWND             hWnd = NULL;
	LONG             Styles = 0;
	WINDOWPLACEMENT  WindowPlacement;
	ImGuiMouseCursor MouseCursor = ImGuiMouseCursor_Arrow;
	bool             ShowCursor = true;
	UINT             KeyboardCodePage = 0;
	DropManager      DropManager;
	bool             Minimized = false;
	bool             Fullscreen = false;
};
static WindowData G;

static void get_xy(LPARAM lParam, int *x, int *y) {
	*x = (short)(lParam & 0xffff); 
	*y = (short)((lParam>>16) & 0xffff); 
}

static void UpdateKeyboardCodePage() {
	HKL keyboard_layout = ::GetKeyboardLayout(0);
	LCID keyboard_lcid = MAKELCID(HIWORD(keyboard_layout), SORT_DEFAULT);
	if (::GetLocaleInfoA(keyboard_lcid, (LOCALE_RETURN_NUMBER | LOCALE_IDEFAULTANSICODEPAGE), (LPSTR)&G.KeyboardCodePage, sizeof(G.KeyboardCodePage)) == 0) {
		G.KeyboardCodePage = CP_ACP;
	}
}

static bool IsVkDown(int vk) {
	return (::GetKeyState(vk) & 0x8000) != 0;
}

static ImGuiKey ScancodeToImGuiKey(int scancode) {
	static const ImGuiKey windows_scancode_table[] = {
		/*	0					1						2						3						4					5						6						7 */
		/*	8					9						A						B						C					D						E						F */
		ImGuiKey_None,			ImGuiKey_Escape,		ImGuiKey_1,				ImGuiKey_2,				ImGuiKey_3,			ImGuiKey_4,				ImGuiKey_5,				ImGuiKey_6,				/* 0 */
		ImGuiKey_7,				ImGuiKey_8,				ImGuiKey_9,				ImGuiKey_0,				ImGuiKey_Minus,		ImGuiKey_Equal,			ImGuiKey_Backspace,		ImGuiKey_Tab,			/* 0 */

		ImGuiKey_Q,				ImGuiKey_W,				ImGuiKey_E,				ImGuiKey_R,				ImGuiKey_T,			ImGuiKey_Y,				ImGuiKey_U,				ImGuiKey_I,				/* 1 */
		ImGuiKey_O,				ImGuiKey_P,				ImGuiKey_LeftBracket,	ImGuiKey_RightBracket,	ImGuiKey_Enter,		ImGuiKey_LeftCtrl,		ImGuiKey_A,				ImGuiKey_S,				/* 1 */

		ImGuiKey_D,				ImGuiKey_F,				ImGuiKey_G,				ImGuiKey_H,				ImGuiKey_J,			ImGuiKey_K,				ImGuiKey_L,				ImGuiKey_Semicolon,		/* 2 */
		ImGuiKey_Apostrophe,	ImGuiKey_GraveAccent,	ImGuiKey_LeftShift,		ImGuiKey_Backslash,		ImGuiKey_Z,			ImGuiKey_X,				ImGuiKey_C,				ImGuiKey_V,				/* 2 */

		ImGuiKey_B,				ImGuiKey_N,				ImGuiKey_M,				ImGuiKey_Comma,			ImGuiKey_Period,	ImGuiKey_Slash,			ImGuiKey_RightShift,	ImGuiKey_PrintScreen,	/* 3 */
		ImGuiKey_LeftAlt,		ImGuiKey_Space,			ImGuiKey_CapsLock,		ImGuiKey_F1,			ImGuiKey_F2,		ImGuiKey_F3,			ImGuiKey_F4,			ImGuiKey_F5,			/* 3 */

		ImGuiKey_F6,			ImGuiKey_F7,			ImGuiKey_F8,			ImGuiKey_F9,			ImGuiKey_F10,		ImGuiKey_NumLock,		ImGuiKey_ScrollLock,	ImGuiKey_Home,		/* 4 */
		ImGuiKey_UpArrow,		ImGuiKey_PageUp,		ImGuiKey_None,			ImGuiKey_LeftArrow,		ImGuiKey_None,		ImGuiKey_RightArrow,	ImGuiKey_None,			ImGuiKey_End,		/* 4 */

		ImGuiKey_DownArrow,		ImGuiKey_PageDown,		ImGuiKey_Insert,		ImGuiKey_Delete,		ImGuiKey_None,		ImGuiKey_None,			ImGuiKey_None,			ImGuiKey_F11,		/* 5 */
		ImGuiKey_F12,			ImGuiKey_Pause,			ImGuiKey_None,			ImGuiKey_None,			ImGuiKey_None,		ImGuiKey_None,			ImGuiKey_None,			ImGuiKey_None,		/* 5 */

		ImGuiKey_None,			ImGuiKey_None,			ImGuiKey_None,			ImGuiKey_None,			ImGuiKey_F13,		ImGuiKey_F14,			ImGuiKey_F15,			ImGuiKey_F16,		/* 6 */
		ImGuiKey_F17,			ImGuiKey_F18,			ImGuiKey_F19,			ImGuiKey_None,			ImGuiKey_None,		ImGuiKey_None,			ImGuiKey_None,			ImGuiKey_None,		/* 6 */

		ImGuiKey_None,			ImGuiKey_None,			ImGuiKey_None,			ImGuiKey_None,			ImGuiKey_None,		ImGuiKey_None,			ImGuiKey_None,			ImGuiKey_None,		/* 7 */
		ImGuiKey_None,			ImGuiKey_None,			ImGuiKey_None,			ImGuiKey_None,			ImGuiKey_None,		ImGuiKey_None,			ImGuiKey_None,			ImGuiKey_None		/* 7 */
	};
	return (scancode >= 0 && scancode < 128) ? windows_scancode_table[scancode] : ImGuiKey_None;
}

static ImGuiKey ToImGuiKey(WPARAM wParam) {
    switch (wParam) {
        case VK_TAB: return ImGuiKey_Tab;
        case VK_LEFT: return ImGuiKey_LeftArrow;
        case VK_RIGHT: return ImGuiKey_RightArrow;
        case VK_UP: return ImGuiKey_UpArrow;
        case VK_DOWN: return ImGuiKey_DownArrow;
        case VK_PRIOR: return ImGuiKey_PageUp;
        case VK_NEXT: return ImGuiKey_PageDown;
        case VK_HOME: return ImGuiKey_Home;
        case VK_END: return ImGuiKey_End;
        case VK_INSERT: return ImGuiKey_Insert;
        case VK_DELETE: return ImGuiKey_Delete;
        case VK_BACK: return ImGuiKey_Backspace;
        case VK_SPACE: return ImGuiKey_Space;
        case VK_RETURN: return ImGuiKey_Enter;
        case VK_ESCAPE: return ImGuiKey_Escape;
        case VK_OEM_7: return ImGuiKey_Apostrophe;
        case VK_OEM_COMMA: return ImGuiKey_Comma;
        case VK_OEM_MINUS: return ImGuiKey_Minus;
        case VK_OEM_PERIOD: return ImGuiKey_Period;
        case VK_OEM_2: return ImGuiKey_Slash;
        case VK_OEM_1: return ImGuiKey_Semicolon;
        case VK_OEM_PLUS: return ImGuiKey_Equal;
        case VK_OEM_4: return ImGuiKey_LeftBracket;
        case VK_OEM_5: return ImGuiKey_Backslash;
        case VK_OEM_6: return ImGuiKey_RightBracket;
        case VK_OEM_3: return ImGuiKey_GraveAccent;
        case VK_CAPITAL: return ImGuiKey_CapsLock;
        case VK_SCROLL: return ImGuiKey_ScrollLock;
        case VK_NUMLOCK: return ImGuiKey_NumLock;
        case VK_SNAPSHOT: return ImGuiKey_PrintScreen;
        case VK_PAUSE: return ImGuiKey_Pause;
        case VK_NUMPAD0: return ImGuiKey_Keypad0;
        case VK_NUMPAD1: return ImGuiKey_Keypad1;
        case VK_NUMPAD2: return ImGuiKey_Keypad2;
        case VK_NUMPAD3: return ImGuiKey_Keypad3;
        case VK_NUMPAD4: return ImGuiKey_Keypad4;
        case VK_NUMPAD5: return ImGuiKey_Keypad5;
        case VK_NUMPAD6: return ImGuiKey_Keypad6;
        case VK_NUMPAD7: return ImGuiKey_Keypad7;
        case VK_NUMPAD8: return ImGuiKey_Keypad8;
        case VK_NUMPAD9: return ImGuiKey_Keypad9;
        case VK_DECIMAL: return ImGuiKey_KeypadDecimal;
        case VK_DIVIDE: return ImGuiKey_KeypadDivide;
        case VK_MULTIPLY: return ImGuiKey_KeypadMultiply;
        case VK_SUBTRACT: return ImGuiKey_KeypadSubtract;
        case VK_ADD: return ImGuiKey_KeypadAdd;
        case VK_LSHIFT: return ImGuiKey_LeftShift;
        case VK_LCONTROL: return ImGuiKey_LeftCtrl;
        case VK_LMENU: return ImGuiKey_LeftAlt;
        case VK_LWIN: return ImGuiKey_LeftSuper;
        case VK_RSHIFT: return ImGuiKey_RightShift;
        case VK_RCONTROL: return ImGuiKey_RightCtrl;
        case VK_RMENU: return ImGuiKey_RightAlt;
        case VK_RWIN: return ImGuiKey_RightSuper;
        case VK_APPS: return ImGuiKey_Menu;
		case '0': return ImGuiKey_0;
		case '1': return ImGuiKey_1;
		case '2': return ImGuiKey_2;
		case '3': return ImGuiKey_3;
		case '4': return ImGuiKey_4;
		case '5': return ImGuiKey_5;
		case '6': return ImGuiKey_6;
		case '7': return ImGuiKey_7;
		case '8': return ImGuiKey_8;
		case '9': return ImGuiKey_9;
		case 'A': return ImGuiKey_A;
		case 'B': return ImGuiKey_B;
		case 'C': return ImGuiKey_C;
		case 'D': return ImGuiKey_D;
		case 'E': return ImGuiKey_E;
		case 'F': return ImGuiKey_F;
		case 'G': return ImGuiKey_G;
		case 'H': return ImGuiKey_H;
		case 'I': return ImGuiKey_I;
		case 'J': return ImGuiKey_J;
		case 'K': return ImGuiKey_K;
		case 'L': return ImGuiKey_L;
		case 'M': return ImGuiKey_M;
		case 'N': return ImGuiKey_N;
		case 'O': return ImGuiKey_O;
		case 'P': return ImGuiKey_P;
		case 'Q': return ImGuiKey_Q;
		case 'R': return ImGuiKey_R;
		case 'S': return ImGuiKey_S;
		case 'T': return ImGuiKey_T;
		case 'U': return ImGuiKey_U;
		case 'V': return ImGuiKey_V;
		case 'W': return ImGuiKey_W;
		case 'X': return ImGuiKey_X;
		case 'Y': return ImGuiKey_Y;
		case 'Z': return ImGuiKey_Z;
        case VK_F1: return ImGuiKey_F1;
        case VK_F2: return ImGuiKey_F2;
        case VK_F3: return ImGuiKey_F3;
        case VK_F4: return ImGuiKey_F4;
        case VK_F5: return ImGuiKey_F5;
        case VK_F6: return ImGuiKey_F6;
        case VK_F7: return ImGuiKey_F7;
        case VK_F8: return ImGuiKey_F8;
        case VK_F9: return ImGuiKey_F9;
        case VK_F10: return ImGuiKey_F10;
        case VK_F11: return ImGuiKey_F11;
        case VK_F12: return ImGuiKey_F12;
        case VK_F13: return ImGuiKey_F13;
        case VK_F14: return ImGuiKey_F14;
        case VK_F15: return ImGuiKey_F15;
        case VK_F16: return ImGuiKey_F16;
        case VK_F17: return ImGuiKey_F17;
        case VK_F18: return ImGuiKey_F18;
        case VK_F19: return ImGuiKey_F19;
        case VK_F20: return ImGuiKey_F20;
        case VK_F21: return ImGuiKey_F21;
        case VK_F22: return ImGuiKey_F22;
        case VK_F23: return ImGuiKey_F23;
        case VK_F24: return ImGuiKey_F24;
        case VK_BROWSER_BACK: return ImGuiKey_AppBack;
        case VK_BROWSER_FORWARD: return ImGuiKey_AppForward;
        default: return ImGuiKey_None;
    }
}

static void UpdateMouseCursor(ImGuiMouseCursor cursor) {
	switch (cursor) {
	default:
	case ImGuiMouseCursor_Arrow:
		::SetCursor(::LoadCursor(nullptr, IDC_ARROW));
		break;
	case ImGuiMouseCursor_TextInput:
		::SetCursor(::LoadCursor(nullptr, IDC_IBEAM));
		break;
	case ImGuiMouseCursor_ResizeAll:
		::SetCursor(::LoadCursor(nullptr, IDC_SIZEALL));
		break;
	case ImGuiMouseCursor_ResizeEW:
		::SetCursor(::LoadCursor(nullptr, IDC_SIZEWE));
		break;
	case ImGuiMouseCursor_ResizeNS:
		::SetCursor(::LoadCursor(nullptr, IDC_SIZENS));
		break;
	case ImGuiMouseCursor_ResizeNESW:
		::SetCursor(::LoadCursor(nullptr, IDC_SIZENESW));
		break;
	case ImGuiMouseCursor_ResizeNWSE:
		::SetCursor(::LoadCursor(nullptr, IDC_SIZENWSE));
		break;
	case ImGuiMouseCursor_Hand:
		::SetCursor(::LoadCursor(nullptr, IDC_HAND));
		break;
	case ImGuiMouseCursor_NotAllowed:
		::SetCursor(::LoadCursor(nullptr, IDC_NO));
		break;
	case ImGuiMouseCursor_None:
		::SetCursor(nullptr);
		break;
	}
}

static LRESULT CALLBACK WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) {
	lua_State* L = NULL;
	switch (message) {
	case WM_CREATE: {
		LPCREATESTRUCTA cs = (LPCREATESTRUCTA)lParam;
		L = (lua_State*)cs->lpCreateParams;
		SetWindowLongPtr(hWnd, GWLP_USERDATA, (LONG_PTR)L);
		RECT r;
		GetClientRect(hWnd, &r);
		window_message_init(L, hWnd, hWnd, NULL, NULL, r.right-r.left, r.bottom-r.top);
		break;
	}
	case WM_DESTROY:
		L = (lua_State*)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		PostQuitMessage(0);
		window_message_exit(L);
		return 0;
	case WM_MOUSEWHEEL: {
		L = (lua_State*)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		struct ant::window::msg_mousewheel msg;
		msg.delta = 1.0f * GET_WHEEL_DELTA_WPARAM(wParam) / WHEEL_DELTA;
		get_xy(lParam, &msg.x, &msg.y);
		ant::window::input_message(L, msg);
		break;
	}
	case WM_MOUSEMOVE:
		L = (lua_State*)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		struct ant::window::msg_mousemove msg;
		msg.what = ant::window::mouse_buttons::none;
		get_xy(lParam, &msg.x, &msg.y);
		if (wParam & MK_LBUTTON) {
			msg.what |= ant::window::mouse_buttons::left;
		}
		if (wParam & MK_MBUTTON) {
			msg.what |= ant::window::mouse_buttons::middle;
		}
		if (wParam & MK_RBUTTON) {
			msg.what |= ant::window::mouse_buttons::right;
		}
		ant::window::input_message(L, msg);
		break;
	case WM_LBUTTONDOWN:
	case WM_MBUTTONDOWN:
	case WM_RBUTTONDOWN:{
		L = (lua_State*)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		struct ant::window::msg_mouseclick msg;
		switch (message) {
		case WM_LBUTTONDOWN:
			msg.what = ant::window::mouse_button::left;
			break;
		case WM_MBUTTONDOWN:
			msg.what = ant::window::mouse_button::middle;
			break;
		case WM_RBUTTONDOWN:
			msg.what = ant::window::mouse_button::right;
			break;
		default:
			std::unreachable();
		}
		msg.state = ant::window::mouse_state::down;
		get_xy(lParam, &msg.x, &msg.y);
		ant::window::input_message(L, msg);
		break;
	}
	case WM_LBUTTONUP:
	case WM_MBUTTONUP:
	case WM_RBUTTONUP: {
		L = (lua_State*)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		struct ant::window::msg_mouseclick msg;
		switch (message) {
		case WM_LBUTTONUP:
			msg.what = ant::window::mouse_button::left;
			break;
		case WM_MBUTTONUP:
			msg.what = ant::window::mouse_button::middle;
			break;
		case WM_RBUTTONUP:
			msg.what = ant::window::mouse_button::right;
			break;
		default:
			std::unreachable();
		}
		msg.state = ant::window::mouse_state::up;
		get_xy(lParam, &msg.x, &msg.y);
		ant::window::input_message(L, msg);
		break;
	}
	case WM_KEYDOWN:
	case WM_KEYUP: {
		L = (lua_State*)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		const bool is_key_down = message == WM_KEYDOWN;
		uint8_t press;
		if (message == WM_KEYUP) {
			press = 0;
		}
		else {
			press = (lParam & (1 << 30))? 2: 1;
		}
		int vk = (int)wParam;
		struct ant::window::msg_keyboard msg;
		msg.press = press;
		msg.state = ant::window::get_keystate(
			GetKeyState(VK_CONTROL) < 0,
			GetKeyState(VK_SHIFT) < 0,
			GetKeyState(VK_MENU) < 0,
			(GetKeyState(VK_LWIN) < 0) || (GetKeyState(VK_RWIN) < 0),
			lParam & (0x1 << 24)
		);
		if (vk == VK_SHIFT) {
			if (IsVkDown(VK_LSHIFT) == is_key_down) {
				msg.key = ImGuiKey_LeftShift;
				ant::window::input_message(L, msg);
			}
			if (IsVkDown(VK_RSHIFT) == is_key_down) {
				msg.key = ImGuiKey_RightShift;
				ant::window::input_message(L, msg);
			}
		}
		else if (vk == VK_CONTROL) {
			if (IsVkDown(VK_LCONTROL) == is_key_down) {
				msg.key = ImGuiKey_LeftCtrl;
				ant::window::input_message(L, msg);
			}
			if (IsVkDown(VK_RCONTROL) == is_key_down) {
				msg.key = ImGuiKey_RightCtrl;
				ant::window::input_message(L, msg);
			}
		}
		else if (vk == VK_MENU) {
			if (IsVkDown(VK_LMENU) == is_key_down) {
				msg.key = ImGuiKey_LeftAlt;
				ant::window::input_message(L, msg);
			}
			if (IsVkDown(VK_RMENU) == is_key_down) {
				msg.key = ImGuiKey_RightAlt;
				ant::window::input_message(L, msg);
			}
		}
		else {
			auto k = ToImGuiKey(vk);
			if (k == ImGuiKey_None) {
				k = ScancodeToImGuiKey((lParam >> 16) & 0xff);
			}
			msg.key = k;
			ant::window::input_message(L, msg);
		}
		break;
	}
	case WM_SIZE: {
		L = (lua_State*)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		int x = LOWORD(lParam);
		int y = HIWORD(lParam);
		if (wParam == SIZE_MINIMIZED) {
			G.Minimized = true;
			ant::window::input_message(L, {ant::window::suspend::will_suspend});
			ant::window::input_message(L, {ant::window::suspend::did_suspend});
		}
		else if (G.Minimized) {
			G.Minimized = false;
			ant::window::input_message(L, {ant::window::suspend::will_resume});
			ant::window::input_message(L, {ant::window::suspend::did_resume});
		}
		else {
			window_message_size(L, x, y);
		}
		break;
	}
	case WM_INPUTLANGCHANGE:
		UpdateKeyboardCodePage();
		break;
	case WM_CHAR: {
		L = (lua_State*)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		if (::IsWindowUnicode(hWnd)) {
			if (wParam > 0 && wParam < 0x10000) {
				struct ant::window::msg_inputchar msg;
				msg.what = ant::window::inputchar_type::utf16;
				msg.code = (uint16_t)wParam;
				ant::window::input_message(L, msg);
			}
		} else {
			wchar_t wch = 0;
			::MultiByteToWideChar(G.KeyboardCodePage, MB_PRECOMPOSED, (char*)&wParam, 1, &wch, 1);
			struct ant::window::msg_inputchar msg;
			msg.what = ant::window::inputchar_type::native;
			msg.code = (uint16_t)wch;
			ant::window::input_message(L, msg);
		}
		break;
	}
	case WM_SETFOCUS:
	case WM_KILLFOCUS: {
		L = (lua_State*)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		struct ant::window::msg_focus msg;
		msg.focused = message == WM_SETFOCUS;
		ant::window::input_message(L, msg);
		break;
	}
	case WM_SETCURSOR:
		if (LOWORD(lParam) == HTCLIENT) {
			UpdateMouseCursor(G.MouseCursor);
			return 1;
		}
		return 0;
	default:
		break;
	}
	return DefWindowProcW(hWnd, message, wParam, lParam);
}

static BOOL CALLBACK EnumFunc(HMONITOR monitor, HDC, LPRECT, LPARAM dwData) {
	std::vector<MONITORINFO>& monitors = *reinterpret_cast<std::vector<MONITORINFO>*>(dwData);
	MONITORINFO info = {};
	info.cbSize = sizeof(MONITORINFO);
	if (!::GetMonitorInfoW(monitor, &info))
		return TRUE;
	if ((info.dwFlags & MONITORINFOF_PRIMARY) && !monitors.empty())
		monitors.insert(monitors.begin(), 1, info);
	else
		monitors.push_back(info);
	return TRUE;
}

static RECT createWindowRect(const char *size) {
	std::vector<MONITORINFO> monitors;
	::EnumDisplayMonitors(nullptr, nullptr, EnumFunc, reinterpret_cast<LPARAM>(&monitors));
	auto& monitor = monitors[0];
	LONG work_w = monitor.rcWork.right - monitor.rcWork.left;
	LONG work_h = monitor.rcWork.bottom - monitor.rcWork.top;
	LONG window_w, window_h;

	int w, h;
	if (size && sscanf(size, "%dx%d", &w, &h) == 2) {
		window_w = w;
		window_h = h;
	} else {
		window_w = (LONG)(work_w * 0.7f);
		window_h = (LONG)(work_h * 0.7f);
		
		// Set window to 16:9
		
		if (window_w * 9 > window_h * 16) {
 			window_w = window_h * 16 / 9;
		} else {
			window_h = window_w * 9 / 16;
		}
	}
	RECT rect;
	rect.left = monitor.rcWork.left + (work_w - window_w) / 2;
	rect.right = rect.left + window_w;
	rect.top = monitor.rcWork.top + (work_h - window_h) / 2;
	rect.bottom = rect.top + window_h;
	AdjustWindowRect(&rect, WS_OVERLAPPEDWINDOW, 0);
	return rect;
}

bool window_init(lua_State* L, const char *size) {
	if (FAILED(OleInitialize(NULL))) {
		return false;
	}
	HICON icon = ::LoadIcon(::GetModuleHandle(NULL), MAKEINTRESOURCE(101));
	if (icon == NULL) {
		icon = ::LoadIcon(NULL, IDI_APPLICATION);
	}
	WNDCLASSEXW wndclass;
	memset(&wndclass, 0, sizeof(wndclass));
	wndclass.cbSize = sizeof(wndclass);
	wndclass.style = CS_HREDRAW | CS_VREDRAW;// | CS_OWNDC;
	wndclass.lpfnWndProc = WndProc;
	wndclass.hInstance = GetModuleHandleW(0);
	wndclass.hIcon = icon;
	wndclass.hCursor = LoadCursorW(NULL, (LPCWSTR)IDC_ARROW);
	wndclass.lpszClassName = CLASSNAME;
	wndclass.hIconSm = icon;
	RegisterClassExW(&wndclass);

	RECT rect = createWindowRect(size);
	HWND wnd = CreateWindowExW(0, CLASSNAME, NULL,
		WS_OVERLAPPEDWINDOW,
		rect.left, rect.top,
		rect.right-rect.left,
		rect.bottom-rect.top,
		0, 0,
		GetModuleHandleW(0),
		L);
	if (wnd == NULL) {
		return false;
	}
	G.hWnd = wnd;
	ShowWindow(wnd, SW_SHOWDEFAULT);
	UpdateWindow(wnd);
	G.DropManager.Register(wnd, L);
	UpdateKeyboardCodePage();
	return true;
}

void window_close() {
	G.DropManager.Revoke();
	UnregisterClassW(CLASSNAME, GetModuleHandleW(0));
	if (!G.ShowCursor) {
		::ShowCursor(TRUE);
	}
}

bool window_peek_message() {
	MSG msg;
	for (;;) {
		if (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE)) {
			if (msg.message == WM_QUIT)
				return false;
			TranslateMessage(&msg);
			DispatchMessageW(&msg);
		}
		else {
			return true;
		}
	}
}

static void window_set_cursor(int cursor) {
	G.MouseCursor = (ImGuiMouseCursor)cursor;
}

static void window_set_title(bee::zstring_view title) {
    ::SetWindowTextW(G.hWnd, bee::wtf8::u2w(title).c_str());
}

static void window_show_cursor(bool show) {
	if (G.ShowCursor != show) {
		G.ShowCursor = show;
		::ShowCursor(show ? TRUE : FALSE);
	}
}

static void window_set_fullscreen(bool fullscreen) {
	if (fullscreen) {
		if (!G.Fullscreen) {
			G.Styles = ::GetWindowLongW(G.hWnd, GWL_STYLE);
			::GetWindowPlacement(G.hWnd, &G.WindowPlacement);
		}
	}

	RECT fullrect = { 0 };
	::SetRect(&fullrect, 0, 0, ::GetSystemMetrics(SM_CXSCREEN), ::GetSystemMetrics(SM_CYSCREEN));

	WINDOWPLACEMENT newPlacement = G.WindowPlacement;
	newPlacement.showCmd = SW_SHOWNORMAL;
	newPlacement.rcNormalPosition = fullrect;

	if (fullscreen) {
		::SetWindowLongW(G.hWnd, GWL_STYLE, WS_VISIBLE);
		::SetWindowPlacement(G.hWnd, &newPlacement);
	}
	else {
		if (G.Fullscreen) {
			::SetWindowLongW(G.hWnd, GWL_STYLE, G.Styles);
			::SetWindowPlacement(G.hWnd, &G.WindowPlacement);
		}
	}
	G.Fullscreen = fullscreen;
}

void ant::window::set_message(ant::window::set_msg& msg) {
	switch (msg.type) {
	case ant::window::set_msg::type::cursor:
		window_set_cursor(msg.cursor);
		break;
	case ant::window::set_msg::type::title:
		window_set_title(msg.title);
		break;
	case ant::window::set_msg::type::fullscreen:
		window_set_fullscreen(msg.fullscreen);
		break;
	case ant::window::set_msg::type::show_cursor:
		window_show_cursor(msg.show_cursor);
		break;
	default:
		break;
	}
}

