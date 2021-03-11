#ifndef cube_sphere_h
#define cube_sphere_h

#define NEIGHBOR_N 0
#define NEIGHBOR_E 1
#define NEIGHBOR_S 2
#define NEIGHBOR_W 3

//           0 N
//            ^
//            |
//     3 W <--+--> 1 E
//            |
//            V
//           2 S

//         ------
//        |      |
//        |  2 U |
//        |  (1) |
//  ------+------+------+------
// |      |      |      |      |
// |  1 B |  4 L |  0 F |  5 R |
// |  (4) |  (5) |  (6) |  (7) |
//  ------+------+------+------
//        |      |
//        |  3 D |
//        |  (9) |
//         ------

#define FACE_FRONT 0
#define FACE_BACK 1
#define FACE_UP 2
#define FACE_DOWN 3
#define FACE_LEFT 4
#define FACE_RIGHT 5

struct cubesphere_coord {
	int faceid;
	int x;
	int y;
};

void cubesphere_neighbor(int n, int index, int out[4]);
void cubesphere_coord(int n, int index, struct cubesphere_coord *coord);

#endif
