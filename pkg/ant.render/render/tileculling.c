#include "tileculling.h"
#include <stdint.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include <math.h>

#define TILE_LENGTH 128
#define CHANGE_TILE_ID 0xffff
#define MAX_ID 0x10000

struct tile {
	uint8_t dirty_count;
	uint8_t last_count;
	uint16_t slot;
};

struct id_list {
	uint16_t id;
	uint16_t next;
};

struct screen {
	int id_max;
	int list_n;
	struct id_list list[MAX_ID];
	uint64_t id_mask[MAX_ID/8];
	struct tile t[TILE_LENGTH][TILE_LENGTH];
	unsigned char mask[TILE_LENGTH * TILE_LENGTH];
};

struct screen *
screen_new() {
	struct screen *S = (struct screen *)malloc(sizeof(*S));
	if (S == NULL)
		return NULL;
	memset(S, 0, sizeof(*S));
	return S;
}

void
screen_delete(struct screen *S) {
	free(S);
}

static inline void
change(struct screen *S, int x, int y) {
	struct tile *t = &S->t[y][x];
	t->slot = CHANGE_TILE_ID;
	if (t->dirty_count < 255) {
		++t->dirty_count;
	}
}

static inline void
add_list(struct screen *S, struct tile *t, int id) {
	if (S->list_n >= CHANGE_TILE_ID) {
		t->slot = CHANGE_TILE_ID;
		return;
	}
	int slot = S->list_n++;
	struct id_list *l = &S->list[slot];
	l->id = id;
	l->next = t->slot;
	t->slot = slot;
}

static inline void
mark_change(struct screen *S, int id) {
	int index = id / 8;
	S->id_mask[index] |= 1 << (id % 8);
}

static inline void
mark_change_tile(struct screen *S, struct tile *t, int n) {
	int i;
	int slot = t->slot;
	for (i=0;i<n;i++) {
		struct id_list *s = &S->list[slot];
		mark_change(S, s->id);
		slot = s->next;
	}
}

static inline int
touch(struct screen *S, int id, int x, int y) {
	struct tile *t = &S->t[y][x];
	if (t->slot == CHANGE_TILE_ID)
		return 1;
	++t->dirty_count;
	if (t->dirty_count <= t->last_count && t->dirty_count < 255) {
		add_list(S, t, id);
		return 0;
	}
	mark_change_tile(S, t, t->dirty_count - 1);
	t->slot = CHANGE_TILE_ID;
	return 1;
}

struct grid_rect {
	int x1;
	int y1;
	int x2;
	int y2;
};

static inline int
intcoord(struct screen *S, const float rect[4], struct grid_rect *r) {
	float x2 = rect[2] + rect[0];
	float y2 = rect[3] + rect[1];
	if (rect[0] < 0) {
		r->x1 = 0;
	} else {
		r->x1 = floorf(rect[0] * TILE_LENGTH);
	}
	if (rect[1] < 0) {
		r->y1 = 0;
	} else {
		r->y1 = floorf(rect[1] * TILE_LENGTH);
	}
	if (x2 < 0 || y2 < 0)
		return 1;
	r->x2 = ceilf(x2 * TILE_LENGTH);
	if (r->x2 >= TILE_LENGTH)
		r->x2 = TILE_LENGTH - 1;
	r->y2 = ceilf(x2 * TILE_LENGTH);
	if (r->y2 >= TILE_LENGTH)
		r->y2 = TILE_LENGTH - 1;
	return 0;
}

void
screen_change(struct screen *S, const float rect[4]) {
	struct grid_rect r;
	if (!intcoord(S, rect, &r)) {
		int i,j;
		for (i=r.x1;i<=r.x2;i++) {
			for (j=r.y1;j<=r.y2;j++) {
				change(S, i, j);
			}
		}
	}
}

int
screen_changeless(struct screen *S, const float rect[4]) {
	int id = S->id_max;
	if (id+1 >= MAX_ID) {
		screen_change(S, rect);
		return -1;
	}
	struct grid_rect r;
	if (intcoord(S, rect, &r)) {
		// out of screen
		return -1;
	}

	int i,j;
	int anychange = 0;
	int allchange = 1;
	for (i=r.x1;i<=r.x2;i++) {
		for (j=r.y1;j<=r.y2;j++) {
			if (touch(S, id, i, j)) {
				anychange = 1;
			} else {
				allchange = 0;
			}
		}
	}
	if (allchange)
		return -1;
	if (anychange)
		mark_change(S, id);
	S->id_max++;
	return id;
}

void
screen_submit(struct screen *S) {
	int i;
	int n = TILE_LENGTH * TILE_LENGTH;
	struct tile *t = &S->t[0][0];
	unsigned char *mask = &S->mask[0];
	for (i=0;i<n;i++,t++, mask++) {
		if (t->dirty_count != t->last_count) {
			// changed
			t->last_count = t->dirty_count;
			if (t->slot != CHANGE_TILE_ID) {
				mark_change_tile(S, t, t->dirty_count);
			}
			*mask = 255;
		} else if (t->slot == CHANGE_TILE_ID) {
			*mask = 255;
		} else {
			*mask = 0;
		}
		t->dirty_count = 0;
		t->slot = 0;
	}
}

void
screen_reset(struct screen *S) {
	S->list_n = 0;
	S->id_max = 0;
	memset(S->id_mask, 0, sizeof(S->id_mask));
}

int
screen_query(struct screen *S, int id) {
	assert(id >= 0 && id <= S->id_max);
	int index = id / 8;
	return S->id_mask[index] & ( 1 << ( id % 8 ) );
}

int
screen_masksize(struct screen *S) {
	(void)S;
	return TILE_LENGTH;
}

const unsigned char *
screen_mask(struct screen *S) {
	return S->mask;
}

#ifdef TESTMAIN

#include <stdio.h>

static void
output_grid(struct screen *S) {
	const unsigned char * ptr = screen_mask(S);
	int i,j;
	for (i=0;i<TILE_LENGTH;i++) {
		for (j=0;j<TILE_LENGTH;j++) {
			printf("%c", *ptr ? 'X' : '.');
			++ptr;
		}
		printf("\n");
	}
}

int
main() {
	struct screen *S = screen_new();
	float r1[4] = { 0, 0, 0.5, 0.5 };
	float r2[4] = { 0.1, 0.1, 0.6, 0.6 };
	float r3[4] = { 0.4, 0.4, 0.5, 0.5 };
	
	// frame 1

	screen_change(S, r1);
	screen_change(S, r2);
	screen_change(S, r3);
	screen_submit(S);
	screen_reset(S);

	// frame 2

	screen_changeless(S, r2);
	screen_change(S, r3);

	screen_submit(S);

	output_grid(S);

	screen_delete(S);
	return 0;
}

#endif