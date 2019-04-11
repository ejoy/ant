#include <initguid.h>
#include <windows.h>
#include <shellapi.h>
#include <stdlib.h>
#include <string.h>
#include "shell.h"
#include <commctrl.h>
#include <commoncontrols.h>
#include <stdio.h>



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
	if (!SHGetFileInfo(filename, 0, &sinfo, sizeof(sinfo), SHGFI_ICON | (large ? SHGFI_LARGEICON : SHGFI_SMALLICON)))
		return 0;
	if (large) {
		info->width = GetSystemMetrics(SM_CXICON);
		info->height = GetSystemMetrics(SM_CYICON);
	}
	else {
		info->width = GetSystemMetrics(SM_CXSMICON);
		info->height = GetSystemMetrics(SM_CYSMICON);
	}

	void * dib = create_dib_icon(info, sinfo.hIcon, sinfo.iIcon);
	DestroyIcon(sinfo.hIcon);

	return dib;
}

int 
size_to_flag(int size)
{
	int flag = SHIL_LARGE;
	switch (size)
	{
	case 0:
		flag = SHIL_SMALL;
		break;
	case 2:
		flag = SHIL_EXTRALARGE;
		break;
	case 3:
#if defined(_MSC_VER)
		flag = SHIL_JUMBO;
		break;
#endif
	case 4:
		flag = SHIL_LAST;
		break;
	default:
		break;
	}
	return flag;
}

static HIMAGELIST himls[] = { NULL,NULL, NULL, NULL, NULL,NULL };

boolean 
init_imagelist(int flag) {
	if (himls[flag] == NULL)
	{
		IImageList* imageList;
		HRESULT re;
#if !defined(_MSC_VER)
		// For MinGW:
		static const IID iID_IImageList = { 0x46eb5926, 0x582e, 0x4017, {0x9f, 0xdf, 0xe8, 0x99, 0x8d, 0xaa, 0x9, 0x50} };
#else
		re = SHGetImageList(flag, (&IID_IImageList), (void**)&imageList);
#endif
		if (re!= S_OK)
			return FALSE;
		himls[flag] = IImageListToHIMAGELIST(imageList);
	}
	return TRUE;
}

void release_imagelist() {
	for (int i = 0; i <= SHIL_LAST; i++)
	{
		if (himls[i] != NULL)
		{
			ImageList_Destroy(himls[i]);
			himls[i] = NULL;
		}
	}
	
}

void *
shell_geticon_with_size(const TCHAR *filename, struct icon_info *info, int size) {
	int flag = size_to_flag(size);

	info->handle = NULL;
	SHFILEINFO sinfo;
	sinfo.hIcon = 0;
	if (!SHGetFileInfo(filename, 0, &sinfo, sizeof(sinfo),  SHGFI_SYSICONINDEX))
		return 0;
	
	
	if(!init_imagelist(flag))
	{
		return 0;
	}
	HIMAGELIST himl = himls[flag];
	HICON hicon = ImageList_GetIcon(himl, sinfo.iIcon, ILD_TRANSPARENT);
	ImageList_GetIconSize(himl,&(info->width),&(info->height));
	// info->width = 256;
	// info->height = 256;
	void * dib = create_dib_icon(info, hicon, sinfo.iIcon);
	DestroyIcon(hicon);
	return dib;
}



void
shell_releaseicon(struct icon_info *info) {
	if (info->handle) {
		DeleteObject((HANDLE)info->handle);
		info->handle = NULL;
	}
}

//void shell_co_initialize() {
//	CoInitialize(NULL);
//}
//
//void shell_co_uninitialize() {
//	CoUninitialize();
//}