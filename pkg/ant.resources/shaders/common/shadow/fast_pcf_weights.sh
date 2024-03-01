#ifndef __FAST_PCF_WEIGHTS_SH__
#define __FAST_PCF_WEIGHTS_SH__

#define PCF_FILTER_DISC				1
#define PCF_FILTER_TRIANGLE			2
#define PCF_FILTER_HALFMOON			3
#define PCF_FILTER_GAUSSIAN_LIKE	4
#define PCF_FILTER_UNIFORM			5

#if PCF_FILTER_SIZE == 9

#if PCF_FILTER_TYPE == PCF_FILTER_HALFMOON
static const float W[9][9] = {
    { 0.2,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0 }, 
    { 0.0,0.1,1.0,1.0,1.0,1.0,1.0,0.0,0.0 },
    { 0.0,0.0,0.0,0.5,1.0,1.0,1.0,1.0,0.0 },
    { 0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,0.0 },
    { 0.0,0.0,0.0,0.0,0.5,1.0,1.0,1.0,0.5 },
    { 0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,0.0 },
    { 0.0,0.0,0.0,0.5,1.0,1.0,1.0,0.0,0.0 },
    { 0.0,0.1,1.0,1.0,1.0,1.0,0.0,0.0,0.0 },
    { 0.2,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0 }
};
#elif PCF_FILTER_TYPE == PCF_FILTER_TRIANGLE
static const float W[9][9] = { 
    { 0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0 },
    { 0.0,0.0,0.0,0.5,1.0,0.5,0.0,0.0,0.0 },
    { 0.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,0.0 },
    { 0.0,0.0,0.5,1.0,1.0,1.0,0.5,0.0,0.0 },
    { 0.0,0.0,1.0,1.0,1.0,1.0,1.0,0.0,0.0 },
    { 0.0,0.5,1.0,1.0,1.0,1.0,1.0,0.5,0.0 },
    { 0.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,0.0 },
    { 0.5,1.0,1.0,1.0,1.0,1.0,1.0,1.0,0.5 },
    { 1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0 },
};
#elif PCF_FILTER_TYPE == PCF_FILTER_DISC
static const float W[9][9] = {
    { 0.0,0.0,0.0,0.5,1.0,0.5,0.0,0.0,0.0 }, 
    { 0.0,0.0,1.0,1.0,1.0,1.0,1.0,0.0,0.0 },
    { 0.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,0.0 },
    { 0.5,1.0,1.0,1.0,1.0,1.0,1.0,1.0,0.5 },
    { 1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0 },
    { 0.5,1.0,1.0,1.0,1.0,1.0,1.0,1.0,0.5 },
    { 0.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,0.0 },
    { 0.0,0.0,1.0,1.0,1.0,1.0,1.0,0.0,0.0 },
    { 0.0,0.0,0.0,0.5,1.0,0.5,0.0,0.0,0.0 },
};
#elif PCF_FILTER_TYPE == PCF_FILTER_UNIFORM
static const float W[9][9] = {
    { 1,1,1,1,1,1,1,1,1 }, 
    { 1,1,1,1,1,1,1,1,1 },
    { 1,1,1,1,1,1,1,1,1 },
    { 1,1,1,1,1,1,1,1,1 },
    { 1,1,1,1,1,1,1,1,1 },
    { 1,1,1,1,1,1,1,1,1 },
    { 1,1,1,1,1,1,1,1,1 },
    { 1,1,1,1,1,1,1,1,1 },
    { 1,1,1,1,1,1,1,1,1 },
};
#elif PCF_FILTER_TYPE == PCF_FILTER_GAUSSIAN_LIKE
static const float W[9][9] = {
    { 1,2,2,2,2,2,2,2,1 }, 
    { 2,3,4,4,4,4,4,3,2 },
    { 2,4,5,6,6,6,5,4,2 },
    { 2,4,6,7,8,7,6,4,2 },
    { 2,4,6,8,9,8,6,4,2 },
    { 2,4,6,7,8,7,6,4,2 },
    { 2,4,5,6,6,6,5,4,2 },
    { 2,3,4,4,4,4,4,3,2 },
    { 1,2,2,2,2,2,2,2,1 },
};
#else //!PCF_FILTER_TYPE
#error "Invalid filter type"
#endif //PCF_FILTER_GAUSSIAN_LIKE

#elif PCF_FILTER_SIZE == 7

#if PCF_FILTER_TYPE == PCF_FILTER_HALFMOON
static const float W[7][7] = {
    { 0.2,1.0,1.0,1.0,0.0,0.0,0.0 }, 
    { 0.0,0.0,0.5,1.0,1.0,1.0,0.0 },
    { 0.0,0.0,0.0,1.0,1.0,1.0,0.0 },
    { 0.0,0.0,0.0,0.5,1.0,1.0,0.5 },
    { 0.0,0.0,0.0,1.0,1.0,1.0,0.0 },
    { 0.0,0.0,0.5,1.0,1.0,1.0,0.0 },
    { 0.2,1.0,1.0,1.0,0.0,0.0,0.0 },
};
#elif PCF_FILTER_TYPE == PCF_FILTER_TRIANGLE
static const float W[7][7] = {
    { 0.0,0.0,0.0,1.0,0.0,0.0,0.0 },
    { 0.0,0.0,1.0,1.0,1.0,0.0,0.0 },
    { 0.0,0.5,1.0,1.0,1.0,0.5,0.0 },
    { 0.0,1.0,1.0,1.0,1.0,1.0,0.0 },
    { 0.0,1.0,1.0,1.0,1.0,1.0,0.0 },
    { 0.5,1.0,1.0,1.0,1.0,1.0,0.5 },
    { 1.0,1.0,1.0,1.0,1.0,1.0,1.0 },
};
#elif PCF_FILTER_TYPE == PCF_FILTER_DISC
static const float W[7][7] = {
    { 0.0,0.0,0.5,1.0,0.5,0.0,0.0 }, 
    { 0.0,1.0,1.0,1.0,1.0,1.0,0.0 },
    { 0.5,1.0,1.0,1.0,1.0,1.0,0.5 },
    { 1.0,1.0,1.0,1.0,1.0,1.0,1.0 },
    { 0.5,1.0,1.0,1.0,1.0,1.0,0.5 },
    { 0.0,1.0,1.0,1.0,1.0,1.0,0.0 },
    { 0.0,0.0,0.5,1.0,0.5,0.0,0.0 },
};

#elif PCF_FILTER_TYPE == PCF_FILTER_UNIFORM
static const float W[7][7] = {
    { 1,1,1,1,1,1,1 },
    { 1,1,1,1,1,1,1 },
    { 1,1,1,1,1,1,1 },
    { 1,1,1,1,1,1,1 },
    { 1,1,1,1,1,1,1 },
    { 1,1,1,1,1,1,1 },
    { 1,1,1,1,1,1,1 },
};

#elif PCF_FILTER_TYPE == PCF_FILTER_GAUSSIAN_LIKE
static const float W[7][7] = {
    { 1,2,2,2,2,2,1 }, 
    { 2,5,6,6,6,5,2 },
    { 2,6,7,8,7,6,2 },
    { 2,6,8,9,8,6,2 },
    { 2,6,7,8,7,6,2 },
    { 2,5,6,6,6,5,2 },
    { 1,2,2,2,2,2,1 },
};
#else //!PCF_FILTER_TYPE
#error "Invalid filter type"
#endif //PCF_FILTER_GAUSSIAN_LIKE

#elif PCF_FILTER_SIZE == 5

#if PCF_FILTER_TYPE == PCF_FILTER_HALFMOON
static const float W[5][5] = {
    { 0.2,1.0,1.0,0.0,0.0 }, 
    { 0.0,0.0,1.0,1.0,0.0 },
    { 0.0,0.0,0.5,1.0,0.5 },
    { 0.0,0.0,1.0,1.0,0.0 },
    { 0.2,1.0,1.0,0.0,0.0 },
};

#elif PCF_FILTER_TYPE == PCF_FILTER_TRIANGLE
static const float W[5][5] = { 
    { 0.0,0.0,1.0,0.0,0.0 },
    { 0.0,0.5,1.0,0.5,0.0 },
    { 0.0,1.0,1.0,1.0,0.0 },
    { 0.5,1.0,1.0,1.0,0.5 },
    { 1.0,1.0,1.0,1.0,1.0 },
};

#elif PCF_FILTER_TYPE == PCF_FILTER_DISC
static const float W[5][5] = {
    { 0.0,0.5,1.0,0.5,0.0 },
    { 0.5,1.0,1.0,1.0,0.5 },
    { 1.0,1.0,1.0,1.0,1.0 },
    { 0.5,1.0,1.0,1.0,0.5 },
    { 0.0,0.5,1.0,0.5,0.0 },
};

#elif PCF_FILTER_TYPE == PCF_FILTER_UNIFORM
static const float W[5][5] = {
    { 1,1,1,1,1 }, 
    { 1,1,1,1,1 },
    { 1,1,1,1,1 },
    { 1,1,1,1,1 },
    { 1,1,1,1,1 },
};

#elif PCF_FILTER_TYPE == PCF_FILTER_GAUSSIAN_LIKE
static const float W[5][5] = {
    { 1,2,2,2,1 },
    { 2,7,8,7,2 },
    { 2,8,9,8,2 },
    { 2,7,8,7,2 },
    { 1,2,2,2,1 },
};
#else //!PCF_FILTER_TYPE
#error "Invalid filter type"

#endif //PCF_FILTER_GAUSSIAN_LIKE

#elif PCF_FILTER_SIZE == 3

#if PCF_FILTER_TYPE == PCF_FILTER_HALFMOON
static const float W[3][3] = {
    { 0.2,1.0,0.0 }, 
    { 0.0,0.5,1.0 },
    { 0.2,1.0,0.0 },
};

#elif PCF_FILTER_TYPE == PCF_FILTER_TRIANGLE
static const float W[3][3] = {
    { 0.0,1.0,0.0 },
    { 0.5,1.0,0.5 },
    { 1.0,1.0,1.0 }
};

#elif PCF_FILTER_TYPE == PCF_FILTER_DISC
static const float W[3][3] = {
    { 0.5,1.0,0.5, }, 
    { 1.0,1.0,1.0, },
    { 0.5,1.0,0.5, },
};

#elif PCF_FILTER_TYPE == PCF_FILTER_UNIFORM
static const float W[3][3] = {
    { 1,1,1 }, 
    { 1,1,1 },
    { 1,1,1 },
};
#elif PCF_FILTER_TYPE == PCF_FILTER_GAUSSIAN_LIKE
static const float W[3][3] = {
    { 1,2,1 }, 
    { 2,5,2 },
    { 1,2,1 },
};
#else //!PCF_FILTER_TYPE
#error "Invalid filter type"
#endif //PCF_FILTER_TYPE

#else //PCF_FILTER_SIZE not 3/5/7/9

#error "Invalid PCF_FILTER_SIZE, should only be 3/5/7/9"
#endif //PCF_FILTER_SIZE

#endif //__FAST_PCF_WEIGHTS_SH__