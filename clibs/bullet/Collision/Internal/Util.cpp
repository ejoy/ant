#include "Util.h"
// util function for c handby
inline void vector_copy(plVector3 &dst,btVector3 &src) 
{
	dst[0] = src.getX();
	dst[1] = src.getY();
	dst[2] = src.getZ();
}
