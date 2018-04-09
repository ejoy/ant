#ifndef ejoy_conversion_h
#define ejoy_conversion_h

union matrix44;
struct euler;

extern union matrix44*
euler_to_matrix44(const struct euler *e, union matrix44 *m);

extern void
matrix44_to_euler(const union matrix44 *m, struct euler *e);

extern void 
euler_to_quaternion(const struct euler *e, struct quaternion *q);

#endif //ejoy_conversion_h