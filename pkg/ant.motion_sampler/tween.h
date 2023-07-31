#ifndef __TWEEN_H__
#define __TWEEN_H__

enum tween_type { None, Back, Bounce, Circular, Cubic, Elastic, Exponential, Linear, Quadratic, Quartic, Quintic, Sine };
float tween(float t, tween_type type_in, tween_type type_out);

#endif //!__TWEEN_H__