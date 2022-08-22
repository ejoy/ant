#pragma once

#include <time.h>
#include <Foundation/Foundation.h>

inline int writelog(const char* catalog, const char* msg) {
    char suffix[256];
    time_t t = time(NULL);
    struct tm *tmp = localtime(&t);
    if (tmp == NULL) {
        return 1;
    }
    if (strftime(suffix, sizeof(suffix), "_%Y%m%d_%H%M%S.log", tmp) == 0) {
        return 1;
    }
    NSArray* array = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if ([array count] <= 0) {
        return 1;
    }
    NSURL* url = [array objectAtIndex:0];
    url = [url URLByAppendingPathComponent:@"/"];
    url = [url URLByAppendingPathComponent:[NSString stringWithUTF8String: catalog]];
    url = [url URLByAppendingPathComponent:[NSString stringWithUTF8String: suffix]];
    FILE* f = fopen([url fileSystemRepresentation], "a+");
    if (!f) {
        return 1;
    }
    fputs(msg, f);
    fclose(f);
    return 0;
}
