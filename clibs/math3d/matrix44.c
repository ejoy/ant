#include "matrix44.h"
#include "conversion.h"

union matrix44 *
matrix44_rot(union matrix44 *m, const struct euler *e) {
	union matrix44 t;
	return matrix44_mul(m, m, euler_to_matrix44(e, &t));
}
