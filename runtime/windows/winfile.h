#ifndef windows_utf8_file_h
#define windows_utf8_file_h

#include <stdio.h>

#define WFILE_NONE 0
#define WFILE_FILE 1
#define WFILE_DIR 2
#define WFILE_UNKNOWN 3

int wfile_personaldir(char *utf8path, int sz);
int wfile_concat(char *utf8path, int sz, const char *path);
int wfile_mkdir(const char *utf8path);
FILE * wfile_open(const char *utf8path, const char *mode);
int wfile_type(const char *utf8path);

#endif