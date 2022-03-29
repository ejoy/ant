#ifndef __EFFEKSEER_COMPATIBLITY_H__
#define __EFFEKSEER_COMPATIBLITY_H__

#include "../Effekseer.EffectNode.h"
#include "../Effekseer.InternalStruct.h"
#include "BinaryVersion.h"

namespace Effekseer
{
inline void LoadFloatEasing(ParameterEasingFloat& param, uint8_t*& pos, int version)
{
	if (version >= Version16Alpha9)
	{
		int32_t size = 0;
		memcpy(&size, pos, sizeof(int));
		pos += sizeof(int);

		param.Load(pos, size, version);
		pos += size;
	}
	else
	{
		param.Load(pos, sizeof(easing_float), version);
		pos += sizeof(easing_float);
	}
}
} // namespace Effekseer

#endif