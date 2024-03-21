#ifndef __FILTERING_SH__
#define __FILTERING_SH__

#ifdef SM_PCF
#include "common/shadow/pcf.sh"
#endif //SM_PCF

#if defined(SM_VSM) || defined(SM_ESM)
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

#ifdef SM_ESM
	return ESM(s_shadowmap, shadowcoord, u_depthMultiplier, cascadeidx);
#endif //SM_ESM

#ifdef SM_VSM
	return VSM(s_shadowmap, shadowcoord, 1, 0.012, cascadeidx);
#endif //SM_VSM

	return 0.0;
}

#endif //__FILTERING_SH__