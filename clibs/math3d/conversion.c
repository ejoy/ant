#include "util.h"
#include "euler.h"
#include "matrix44.h"
#include "conversion.h"

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

#define C m->c

	C[0][0] = cy*cr + sy*sp*sr;
	C[0][1] = sr*cp;
	C[0][2] = -sy*cr + cy*sp*sr;

	C[1][0] = -cy*sr + sy*sp*cr;
	C[1][1] = cr*cp;
	C[1][2] = sr*sy + cy*sp*cr;

	C[2][0] = sy*cp;
	C[2][1] = -sy;
	C[2][2] = cy*cp;
#undef C
	return m;
}

void
matrix44_to_euler(const union matrix44 *m, struct euler *e) {
	float sp = -m->c[2][1];
	if (sp <= -1.f)
		e->pitch = -1.57076f;
	else if (sp >= 1.f)
		e->pitch = 1.57076f;
	else
		e->pitch = asinf(sp);

	if (fabs(sp) > 0.9999f){
		e->roll = 0.f;
		e->yaw = atan2(-m->c[0][2], m->c[0][0]);
	} else {
		e->yaw = atan2(m->c[2][0], m->c[2][2]);
		e->roll = atan2(m->c[0][1], m->c[1][1]);
	}

	euler_to_degree(e);
}

void 
euler_to_quaternion(const struct euler *e, struct quaternion *q) {

}