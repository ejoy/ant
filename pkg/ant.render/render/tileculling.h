#ifndef TILE_CULLING_H
#define TILE_CULLING_H

struct screen;

struct screen * screen_new();
void screen_delete(struct screen *S);
void screen_change(struct screen *S, const float rect[4]);	// x,y,w,h
int screen_changeless(struct screen *S, const float rect[4]);	// w,y,w,h
void screen_submit(struct screen *S);
int screen_query(struct screen *S, int id);
int screen_masksize(struct screen *S);
const unsigned char * screen_mask(struct screen *S);	// masksize * masksize
void screen_reset(struct screen *S);

#endif
