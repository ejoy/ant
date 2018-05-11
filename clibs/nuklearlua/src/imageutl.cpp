#include "imageutl.h"

#define  STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

#define  STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

unsigned char *loadImage( char const *filename, int *x, int *y, int *comp, int req_comp) {
    return  stbi_load(filename, x, y, comp, req_comp);
}

void freeImage(void *data) {
    stbi_image_free(data);
}

int saveImage(char const *filename, int x, int y, int comp, const void *data) {
    return stbi_write_bmp(filename,  x,  y,  comp,data);
}
