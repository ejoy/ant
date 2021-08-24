//=================================================================================================
//
//	MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#include "PCH.h"

#include "Window.h"

namespace SampleFramework11
{

Window::Window(	HINSTANCE hinstance,
				LPCWSTR name,
				DWORD style,
				DWORD exStyle,
				DWORD clientWidth,
				DWORD clientHeight,
				LPCWSTR iconResource,
				LPCWSTR smallIconResource,
				LPCWSTR menuResource,
				LPCWSTR accelResource) :	style(style),
											exStyle(exStyle),
											appName(name),
											hinstance(hinstance),
											hwnd(NULL)
{
	if (hinstance == NULL)
		this->hinstance = GetModuleHandle(NULL);

	INITCOMMONCONTROLSEX cce;
	cce.dwSize = sizeof(INITCOMMONCONTROLSEX);
	cce.dwICC = ICC_BAR_CLASSES|ICC_COOL_CLASSES|ICC_STANDARD_CLASSES|ICC_STANDARD_CLASSES;
	::InitCommonControlsEx ( &cce );

	MakeWindow(iconResource, smallIconResource, menuResource);
	SetClientArea(clientWidth, clientHeight);

	if (accelResource)
	{
		accelTable = ::LoadAccelerators(hinstance, accelResource);
		if (!accelTable)
			throw Win32Exception(::GetLastError());
	}
}

Window::~Window()
{
	::DestroyWindow(hwnd);
	::UnregisterClass(appName.c_str(), hinstance);
}

HWND Window::GetHwnd() const
{
	return hwnd;
}

HMENU Window::GetMenu() const
{
	return ::GetMenu(hwnd);
}

HINSTANCE Window::GetHinstance() const
{
	return hinstance;
}

BOOL Window::IsAlive() const
{
	return ::IsWindow(hwnd);
}

BOOL Window::IsMinimized() const
{
	return ::IsIconic(hwnd);
}

void Window::SetWindowStyle(DWORD newStyle)
{
	if (!::SetWindowLongPtr(hwnd, GWL_STYLE, newStyle))
		throw Win32Exception(::GetLastError());

	style = newStyle;
}

void Window::SetExtendedStyle(DWORD newExStyle)
{
	if (!::SetWindowLongPtr(hwnd, GWL_EXSTYLE, newExStyle))
		throw Win32Exception(::GetLastError());

	exStyle = newExStyle;
}

LONG_PTR Window::GetWindowStyle() const
{
	return GetWindowLongPtr(hwnd, GWL_STYLE);
}

LONG_PTR Window::GetExtendedStyle() const
{
	return GetWindowLongPtr(hwnd, GWL_EXSTYLE);
}

void Window::MakeWindow(LPCWSTR sIconResource, LPCWSTR sSmallIconResource, LPCWSTR sMenuResource)
{

	HICON hIcon = NULL;
	if(sIconResource)
	{
		hIcon = reinterpret_cast<HICON>(::LoadImage(hinstance,
													sIconResource,
													IMAGE_ICON,
													0,
													0,
													LR_DEFAULTCOLOR));
	}

	HICON hSmallIcon = NULL;
	if(sSmallIconResource)
	{
		hIcon = reinterpret_cast<HICON>(::LoadImage(hinstance,
													sSmallIconResource,
													IMAGE_ICON,
													0,
													0,
													LR_DEFAULTCOLOR));
	}

	HCURSOR hCursor = ::LoadCursorW(NULL, IDC_ARROW);

	// Register the window class
    WNDCLASSEX wc = {	sizeof(WNDCLASSEX),
						CS_DBLCLKS,
						WndProc,
						0,
						0,
						hinstance,
						hIcon,
						hCursor,
						NULL,
						sMenuResource,
						appName.c_str(),
						hSmallIcon
					};

	if (!::RegisterClassEx(&wc))
		throw Win32Exception(::GetLastError());

    // Create the application's window
	hwnd = ::CreateWindowEx(exStyle,
							appName.c_str(),
							appName.c_str(),
							style,
							CW_USEDEFAULT,
							CW_USEDEFAULT,
							CW_USEDEFAULT,
							CW_USEDEFAULT,
							NULL,
							NULL,
							hinstance,
							(void*)this
							);

	if(!hwnd)
		throw Win32Exception(::GetLastError());
    }

void Window::SetWindowPos(INT posX, INT posY)
{
	if (!::SetWindowPos(hwnd, HWND_NOTOPMOST, posX, posY, 0, 0, SWP_NOSIZE))
		throw Win32Exception(::GetLastError());
}

void Window::GetWindowPos(INT& posX, INT& posY) const
{
	RECT windowRect;
	if (!::GetWindowRect(hwnd, &windowRect))
		throw Win32Exception(::GetLastError());
	posX = windowRect.left;
	posY = windowRect.top;
}

void Window::ShowWindow(bool show)
{
	INT cmdShow = show ? SW_SHOW : SW_HIDE;

	::ShowWindow(hwnd, cmdShow);
}

void Window::SetClientArea(INT clientX, INT clientY)
{
	RECT windowRect;
	::SetRect( &windowRect, 0, 0, clientX, clientY );

	BOOL bIsMenu = (::GetMenu(hwnd) != NULL);
	if ( !::AdjustWindowRectEx(&windowRect, style, bIsMenu, exStyle))
		throw Win32Exception(::GetLastError());

	if (!::SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, windowRect.right - windowRect.left, windowRect.bottom - windowRect.top, SWP_NOMOVE))
		throw Win32Exception(::GetLastError());
}

void Window::GetClientArea(INT& clientX, INT& clientY) const
{
	RECT clientRect;
	if (!::GetClientRect(hwnd, &clientRect))
		throw Win32Exception(::GetLastError());

	clientX = clientRect.right;
	clientY = clientRect.bottom;
}

void Window::SetWindowTitle(LPCWSTR title)
{
	if (!::SetWindowText(hwnd, title))
		throw Win32Exception(::GetLastError());
}

void Window::SetScrollRanges(	INT scrollRangeX,
								INT scrollRangeY,
								INT posX,
								INT posY	)
{
	INT clientX, clientY;
	GetClientArea(clientX, clientY);

	// Horizontal first
	SCROLLINFO scrollInfo;
	scrollInfo.cbSize = sizeof( SCROLLINFO );
	scrollInfo.fMask = SIF_PAGE|SIF_POS|SIF_RANGE;
	scrollInfo.nMin = 0;
	scrollInfo.nMax = scrollRangeX;
	scrollInfo.nPos = posX;
	scrollInfo.nTrackPos = 0;
	scrollInfo.nPage = static_cast<INT>(((FLOAT) clientX / scrollRangeX) * clientX);
	::SetScrollInfo(hwnd, SB_HORZ, &scrollInfo, true);

	// Then vertical
	scrollInfo.nMax = scrollRangeX;
	scrollInfo.nPos = posY;
	scrollInfo.nPage = static_cast<INT>(((FLOAT) clientY / scrollRangeX) * clientY);
	::SetScrollInfo(hwnd, SB_VERT, &scrollInfo, true);
}

INT	Window::CreateMessageBox(LPCWSTR message, LPCWSTR title, UINT type)
{
	if (title == NULL)
		return ::MessageBox(hwnd, message, appName.c_str(), type);
	else
		return ::MessageBox(hwnd, message, title, type);
}

void Window::Maximize()
{
	::ShowWindow( hwnd, SW_MAXIMIZE );
}

void Window::Destroy()
{
	::DestroyWindow(hwnd);
	::UnregisterClass(appName.c_str(), hinstance);
}

LRESULT Window::MessageHandler(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    if(TwEventWin(hWnd, uMsg, wParam, lParam))
        return 0;

	if(messageCallbacks.find(uMsg) != messageCallbacks.end())
	{
        Callback callback = messageCallbacks[uMsg];
		MsgFunction msgFunction = callback.Function;
		return msgFunction(callback.Context, hWnd, uMsg, wParam, lParam);
	}
	else
	{
		switch (uMsg)
		{
			// Window is being destroyed
			case WM_DESTROY:
				::PostQuitMessage(0);
				return 0;

			// Window is being closed
			case WM_CLOSE:
			{
				DestroyWindow(hwnd);
				return 0;
			}
		}
	}

	return ::DefWindowProc(hwnd, uMsg, wParam, lParam);
}

LRESULT WINAPI Window::WndProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	switch(uMsg)
    {
		case WM_NCCREATE:
		{
			LPCREATESTRUCT pCreateStruct = reinterpret_cast<LPCREATESTRUCT>(lParam);
			Window* pObj = reinterpret_cast<Window*>( pCreateStruct->lpCreateParams);
			::SetWindowLongPtr(hWnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(pCreateStruct->lpCreateParams));
			return ::DefWindowProc(hWnd, uMsg, wParam, lParam);
		}
    }

    Window* pObj = reinterpret_cast<Window*>(GetWindowLongPtr(hWnd, GWLP_USERDATA));
	if (pObj)
		return pObj->MessageHandler(hWnd, uMsg, wParam, lParam);
	else
		return ::DefWindowProc(hWnd, uMsg, wParam, lParam);
}


void Window::MessageLoop()
{
	// Main message loop:
	MSG msg;

	while(PeekMessage(&msg, NULL, 0, 0, PM_REMOVE))
	{
		if(!accelTable || !TranslateAccelerator(msg.hwnd, accelTable, &msg))
		{
			::TranslateMessage( &msg );
			::DispatchMessage( &msg );
		}
	}
}

void Window::RegisterMessageCallback(UINT uMessage, MsgFunction msgFunction, void* context)
{
    Callback callback;
    callback.Function = msgFunction;
    callback.Context = context;
	messageCallbacks[uMessage] = callback;
}

}