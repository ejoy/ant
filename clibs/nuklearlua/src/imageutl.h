#ifndef __IMAGE_UTIL_H__
#define __IMAGE_UTIL_H__

unsigned 
char* loadImage( char const *filename, int *x, int *y, int *comp, int req_comp);
void  freeImage(void *data);
int   saveImage(char const *filename, int x, int y, int comp, const void *data);
#endif
