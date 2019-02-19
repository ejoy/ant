#include <windows.h>
#include <shellapi.h>
#include <stdlib.h>
#include <string.h>
#include "shell.h"

static void *
create_dib_icon(struct icon_info *info, HICON icon, int index) {
	void * data;
	HDC dc = GetDC(NULL);
	HDC dcMem = CreateCompatibleDC(dc);

	BITMAPINFOHEADER bi;
	bi.biSize = sizeof(BITMAPINFOHEADER);
	bi.biWidth = info->width;
	bi.biHeight = -info->height;
	bi.biPlanes = 1;
	bi.biBitCount = 32;
	bi.biCompression = BI_RGB;
	HBITMAP dib = CreateDIBSection(dc, (BITMAPINFO*)&bi, DIB_RGB_COLORS, (VOID**)&data, NULL, 0);

	if (dib == NULL) {
		DeleteDC(dcMem);
		ReleaseDC(NULL, dc);
		return NULL;
	}
	info->handle = (void *)dib;
	HBITMAP hBmpOld = (HBITMAP)SelectObject(dcMem, dib);

	int pixel_count = info->width * info->height * 4;	// rgba
	memset(data, 0, pixel_count);
	DrawIconEx(dcMem, 0, 0, icon, info->width, info->height, index, NULL, DI_NORMAL);
	SelectObject(dcMem, hBmpOld);
	DeleteDC(dcMem);
	ReleaseDC(NULL, dc);
	return data;
}

void *
shell_geticon(const TCHAR *filename, struct icon_info *info, int large) {
	info->handle = NULL;
	SHFILEINFO sinfo;
	if (!SHGetFileInfo(filename, 0, &sinfo, sizeof(sinfo), SHGFI_ICON | (large ? SHGFI_LARGEICON : SHGFI_SMALLICON) ))
		return 0;
	if (large) {
		info->width = GetSystemMetrics(SM_CXICON);
		info->height = GetSystemMetrics(SM_CYICON);
	} else {
		info->width = GetSystemMetrics(SM_CXSMICON);
		info->height = GetSystemMetrics(SM_CYSMICON);
	}

	void * dib = create_dib_icon(info, sinfo.hIcon, sinfo.iIcon);
	DestroyIcon(sinfo.hIcon);

	return dib;
}

void
shell_releaseicon(struct icon_info *info) {
	if (info->handle) {
		DeleteObject((HANDLE)info->handle);	
		info->handle = NULL;
	}
}
