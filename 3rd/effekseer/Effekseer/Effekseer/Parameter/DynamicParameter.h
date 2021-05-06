
#ifndef __EFFEKSEER_DYNAMIC_PARAMETER_H__
#define __EFFEKSEER_DYNAMIC_PARAMETER_H__

#include "../Effekseer.Base.Pre.h"
#include "../Effekseer.InternalStruct.h"

namespace Effekseer
{

/**!
	@brief indexes of dynamic parameter
*/
struct RefMinMax
{
	int32_t Max = -1;
	int32_t Min = -1;
};

//! calculate dynamic equation and assign a result
void ApplyEq(float& dstParam, Effect* e, InstanceGlobal* instg, Instance* parrentInstance, IRandObject* rand, int dpInd, const float& originalParam);

//! calculate dynamic equation and return a result
SIMD::Vec3f ApplyEq(Effect* e,
					InstanceGlobal* instg,
					Instance* parrentInstance,
					IRandObject* rand,
					const int& dpInd,
					const SIMD::Vec3f& originalParam,
					const std::array<float, 3>& scale,
					const std::array<float, 3>& scaleInv);

//! calculate dynamic equation and return a result
random_float ApplyEq(Effect* e, InstanceGlobal* instg, Instance* parrentInstance, IRandObject* rand, const RefMinMax& dpInd, random_float originalParam);

//! calculate dynamic equation and return a result
random_vector3d ApplyEq(Effect* e,
						InstanceGlobal* instg,
						Instance* parrentInstance,
						IRandObject* rand,
						const RefMinMax& dpInd,
						random_vector3d originalParam,
						const std::array<float, 3>& scale,
						const std::array<float, 3>& scaleInv);

//! calculate dynamic equation and return a result
random_int ApplyEq(Effect* e, InstanceGlobal* instg, Instance* parrentInstance, IRandObject* rand, const RefMinMax& dpInd, random_int originalParam);

} // namespace Effekseer

#endif // __EFFEKSEER_PARAMETERS_H__