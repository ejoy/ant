#ifndef ejoy_conversion_h
#define ejoy_conversion_h

union matrix44;
struct euler;
struct quaternion;
extern union matrix44*
euler_to_matrix44(const struct euler *e, union matrix44 *m);

extern struct euler*
matrix44_to_euler(const union matrix44 *m, struct euler *e);

extern struct quaternion*
euler_to_quaternion(const struct euler *e, struct quaternion *q);

extern struct euler*
quaternion_to_euler(const struct quaternion *q, struct euler *e);

#endif //ejoy_conversion_h