#include "util.h"
#include "euler.h"
#include "matrix44.h"
#include "conversion.h"

#define C m->c
union matrix44*
euler_to_matrix44(const struct euler *e, union matrix44 *m) {
	const float p = TO_RADIAN(e->pitch);
	const float y = TO_RADIAN(e->yaw);
	const float r = TO_RADIAN(e->roll);

	const float cp = cosf(p);
	const float sp = sinf(p);

	const float cy = cosf(y);
	const float sy = sinf(y);	

	const float cr = cosf(r);
	const float sr = sinf(r);	

	C[0][0] = cy*cr + sy*sp*sr;
	C[0][1] = sr*cp;
	C[0][2] = -sy*cr + cy*sp*sr;
	C[0][3] = 0.0f;

	C[1][0] = -cy*sr + sy*sp*cr;
	C[1][1] = cr*cp;
	C[1][2] = sr*sy + cy*sp*cr;
	C[1][3] = 0.0f;

	C[2][0] = sy*cp;
	C[2][1] = -sp;
	C[2][2] = cy*cp;
	C[2][3] = 0.0f;

	C[3][0] = C[3][1] = C[3][2] = 0.f;
	C[3][3] = 1.f;
	return m;
}

struct euler*
matrix44_to_euler(const union matrix44 *m, struct euler *e) {
	float sp = -C[2][1];
	if (sp <= -1.f)
		e->pitch = -1.57076f;
	else if (sp >= 1.f)
		e->pitch = 1.57076f;
	else
		e->pitch = asinf(sp);

	if (fabs(sp) > 0.9999f){
		e->roll = 0.f;
		e->yaw = atan2f(-C[0][2], C[0][0]);
        // e->yaw = 0.f;
        // e->roll = atan2f(-C[1][0], C[0][0]);
	} else {
		e->yaw = atan2f(C[2][0], C[2][2]);
		e->roll = atan2f(C[0][1], C[1][1]);
	}

	euler_to_degree(e);
    return e;
}

struct quaternion*
euler_to_quaternion(const struct euler *e, struct quaternion *q) {
    return q;
}