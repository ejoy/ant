#ifndef _PBR_INPUTS_
#define _PBR_INPUTS_
#include "common/inputs.sh"

#ifdef WITH_COLOR_ATTRIB
#   define INPUT_COLOR0    a_color0
#   define OUTPUT_COLOR0   v_color0
#else //!WITH_COLOR_ATTRIB
#   define INPUT_COLOR0
#   define OUTPUT_COLOR0
#endif //WITH_COLOR_ATTRIB

#ifdef USING_LIGHTMAP
#   define INPUT_TEXCOORD1     a_texcoord1
#   define OUTPUT_TEXCOORD1    v_texcoord1
#else //!USING_LIGHTMAP
#   define INPUT_TEXCOORD1
#   define OUTPUT_TEXCOORD1
#endif //USING_LIGHTMAP

#endif //_PBR_INPUTS_
