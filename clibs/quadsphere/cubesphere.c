#include "cubesphere.h"

#include <assert.h>

#define TRANS_0 0
#define TRANS_E 1
#define TRANS_X 2
#define TRANS_EX 3
#define TRANS_Y 4
#define TRANS_EY 5

void
cubesphere_coord(int n, int index, struct cubesphere_coord *coord) {
	int n2 = n * n;
	assert(index >= 0 && index < 6 * n2);
	int face = index / n2 % 6;
	int face_index = index - face * n2;
	int y = face_index / n;
	int x = face_index - y * n;
	coord->faceid = face;
	coord->x = x;
	coord->y = y;
}

void
cubesphere_neighbor(int n, int index, int out[4]) {
	static const int face_neighbor[6][4] = {
		{ FACE_UP,    FACE_RIGHT, FACE_DOWN,  FACE_LEFT  }, // front
		{ FACE_UP,    FACE_LEFT,  FACE_DOWN,  FACE_RIGHT }, // back
		{ FACE_RIGHT, FACE_FRONT, FACE_LEFT,  FACE_BACK  }, // up
		{ FACE_LEFT,  FACE_FRONT, FACE_RIGHT, FACE_BACK  }, // down
		{ FACE_UP,    FACE_FRONT, FACE_DOWN,  FACE_BACK  }, // left
		{ FACE_UP,    FACE_BACK,  FACE_DOWN,  FACE_FRONT }, // right
	};
	// 6 * n * n
	int n2 = n * n;
	struct cubesphere_coord coord;
	cubesphere_coord(n, index, &coord);
	int face = coord.faceid;
	int e = n - 1;
	//			  0  E  X  EX   Y  EY
	int tx[6] = { 0, e, coord.x, e-coord.x, coord.y, e-coord.y };
	int ty[6];
	int i;
	for (i=0;i<6;i++) {
		ty[i] = tx[i] * n;
	}

	// north
	if (coord.y > 0) {
		out[NEIGHBOR_N] = index - n;
	} else {
		int upface = face_neighbor[face][NEIGHBOR_N];
//		printf("UP %d->%d\n",face, upface);
		static const int neighbor[6][2] = {
			{ TRANS_E,  TRANS_EX },	// front: x' = e  , y' = e-x
			{ TRANS_0,  TRANS_X  },	// back : x' = 0  , y' = x
			{ TRANS_EX, TRANS_0  },	// up   : x' = e-x, y' = 0
			{ TRANS_X,  TRANS_E  },	// down : x' = x  , y' = e
			{ TRANS_X,  TRANS_E  },	// left : x' = x  , y' = e
			{ TRANS_EX, TRANS_0  },	// right: x' = e-x, y' = 0
		};
		int col = tx[neighbor[face][0]];
		int row = ty[neighbor[face][1]];
		out[NEIGHBOR_N] = upface * n2 + (col + row);
	}
	// east
	if (coord.x < e) {
		out[NEIGHBOR_E] = index + 1;
	} else {
		int rightface = face_neighbor[face][NEIGHBOR_E];
//		printf("RIGHT %d->%d\n",face, rightface);
		static const int neighbor[6][2] = {
			{ TRANS_0, TRANS_Y },	// front : x' = 0   , y' = y
			{ TRANS_0, TRANS_Y },	// back  : x' = 0   , y' = y
			{ TRANS_EY,TRANS_0 },	// up    : x' = e-y , y' = 0
			{ TRANS_Y, TRANS_E },	// down  : x' = y   , y' = e
			{ TRANS_0, TRANS_Y },	// left  : x' = 0   , y' = y
			{ TRANS_0, TRANS_Y },	// right : x' = 0   , y' = y
		};
		int col = tx[neighbor[face][0]];
		int row = ty[neighbor[face][1]];
		out[NEIGHBOR_E] = rightface * n2 + (col + row);
	}
	// south
	if (coord.y < e) {
		out[NEIGHBOR_S] = index + n;
	} else {
		int downface = face_neighbor[face][NEIGHBOR_S];
//		printf("DOWN %d->%d\n",face, downface);
		static const int neighbor[6][2] = {
			{ TRANS_E, TRANS_X },
			{ TRANS_0, TRANS_EX},
			{ TRANS_X, TRANS_0 },
			{ TRANS_EX,TRANS_E },
			{ TRANS_X, TRANS_0 },
			{ TRANS_EX,TRANS_E },
		};
		int col = tx[neighbor[face][0]];
		int row = ty[neighbor[face][1]];
		out[NEIGHBOR_S] = downface * n2 + (col + row);
	}
	// west
	if (coord.x > 0) {
		out[NEIGHBOR_W] = index - 1;
	} else {
		int leftface = face_neighbor[face][NEIGHBOR_W];
//		printf("LEFT %d->%d\n",face, leftface);
		static const int neighbor[6][2] = {
			{ TRANS_E, TRANS_Y },
			{ TRANS_E, TRANS_Y },
			{ TRANS_Y, TRANS_0 },
			{ TRANS_EY,TRANS_E },
			{ TRANS_E, TRANS_Y },
			{ TRANS_E, TRANS_Y },
		};
		int col = tx[neighbor[face][0]];
		int row = ty[neighbor[face][1]];
		out[NEIGHBOR_W] = leftface * n2 + (col + row);
	}
}
