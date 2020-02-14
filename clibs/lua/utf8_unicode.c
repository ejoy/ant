#include "utf8_unicode.h"

#include <Windows.h>

wchar_t* u2w(const char *str) {
    int len = 0;
    int out_len = 0;
    wchar_t *buf = NULL;
    if (!str) {
        return NULL;
    }
    len = MultiByteToWideChar(CP_UTF8, 0, str, -1, NULL, 0);
    if (len) {
        buf = (wchar_t*)calloc(len, sizeof(wchar_t));
        if (!buf) {
            return NULL;
        }
        out_len = MultiByteToWideChar(CP_UTF8, 0, str, -1, buf, len);
    }
    else {
        len = MultiByteToWideChar(CP_ACP, 0, str, -1, NULL, 0);
        if (len) {
            buf = (wchar_t*)calloc(len, sizeof(wchar_t));
            if (!buf) {
                return NULL;
            }
            out_len = MultiByteToWideChar(CP_ACP, 0, str, -1, buf, len);
        }
    }
    if (out_len < 0) {
        free(buf);
        return NULL;
    }
    return buf;
}

char* w2u(const wchar_t *str)
{
    int len = 0;
    int out_len = 0;
    char *buf = NULL;
    if (!str) {
        return NULL;
    }
    len = WideCharToMultiByte(CP_UTF8, 0, str, -1, NULL, 0, NULL, NULL);
    if (len) {
        buf = (char*)calloc(len, sizeof(char));
        if (!buf) {
            return NULL;
        }
        out_len = WideCharToMultiByte(CP_UTF8, 0, str, -1, buf, len, NULL, NULL);
    }
    else {
        len = WideCharToMultiByte(CP_ACP, 0, str, -1, NULL, 0, NULL, NULL);
        if (len) {
            buf = (char*)calloc(len, sizeof(char));
            if (!buf) {
                return NULL;
            }
            out_len = WideCharToMultiByte(CP_ACP, 0, str, -1, buf, len, NULL, NULL);
        }
    }
    if (out_len < 0) {
        free(buf);
        return NULL;
    }
    return buf;
}
