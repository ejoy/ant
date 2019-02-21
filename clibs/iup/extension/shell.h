#ifndef SHELL_API_H
#define SHELL_API_H

struct icon_info {
	int width;
	int height;
	void * handle;
};

void * shell_geticon(const TCHAR *filename, struct icon_info *info, int large);
void shell_releaseicon(struct icon_info *info);

#endif
