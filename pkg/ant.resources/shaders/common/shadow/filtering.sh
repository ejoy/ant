#ifndef __FILTERING_SH__
#define __FILTERING_SH__

#ifdef SM_PCF
#include "common/shadow/pcf.sh"
#endif //SM_PCF

#if defined(SM_EVSM)
#include "common/shadow/evsm.sh"
#endif //

float sample_visibility(vec4 shadowcoord, uint cascadeidx)
{
#ifdef SM_HARD
	return sample_shadow(s_shadowmap, shadowcoord, cascadeidx);
#endif //SM_HARD

#ifdef SM_PCF
	return shadowPCF(s_shadowmap, shadowcoord, cascadeidx);
#endif //SM_PCF

#ifdef SM_EVSM
	return shadowEVSM(s_shadowmap, shadowcoord, cascadeidx);
#endif //SM_EVSM
	return 0.0;
}

#endif //__FILTERING_SH__