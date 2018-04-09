#include "matrix44.h"
#include "conversion.h"

union matrix44 *
matrix44_rot(union matrix44 *m, const struct euler *e) {
	union matrix44 t;
	return matrix44_mul(m, m, euler_to_matrix44(e, &t));
}

void
matrix44_decompose(const union matrix44 *m, struct vector3 *trans, struct vector3 *rot, struct vector3 *scale ) {
	matrix44_gettrans(m, trans);
	matrix44_getscale(m, scale);

	if( scale->x == 0 || scale->y == 0 || scale->z == 0 ) {
		rot->x = 0;
		rot->y = 0;
		rot->z = 0;
		return;
	}

    struct euler e;
    matrix44_to_euler(m, &e);
    rot->x = e.pitch;
    rot->y = e.yaw;
    rot->z = e.roll;
}