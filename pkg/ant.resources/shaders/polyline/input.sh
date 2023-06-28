#ifndef __POLYLINE_INPUT_SH__
#define __POLYLINE_INPUT_SH__

#ifdef ENABLE_POLYLINE_MASK
#define MASK_UV	v_maskuv
#else	//!ENABLE_POLYLINE_MASK
#define MASK_UV
#endif //ENABLE_POLYLINE_MASK

#ifdef ENABLE_TAA
    #define VELOCITY_PREV_POS v_prev_pos
    #define VELOCITY_CUR_POS v_cur_pos
#else
    #define VELOCITY_PREV_POS
    #define VELOCITY_CUR_POS
#endif

#endif //__POLYLINE_INPUT_SH__