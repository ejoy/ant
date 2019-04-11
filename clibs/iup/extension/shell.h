#ifndef SHELL_API_H
#define SHELL_API_H

struct icon_info {
    int width;
    int height;
    void * handle;
};

void * shell_geticon(const TCHAR *filename, struct icon_info *info, int large);
void shell_releaseicon(struct icon_info *info);
void * shell_geticon_with_size(const TCHAR *filename, struct icon_info *info, int size);
//void shell_co_initialize();
//void shell_co_uninitialize();
int size_to_flag(int size);
#endif
