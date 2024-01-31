#include <cstdint>

static constexpr uint64_t a1 = 0x65d200ce55b19ad8L;
static constexpr uint64_t b1 = 0x4f2162926e40c299L;
static constexpr uint64_t c1 = 0x162dd799029970f8L;
static constexpr uint64_t a2 = 0x68b665e6872bd1f4L;
static constexpr uint64_t b2 = 0xb6cfcf9d79b51db2L;
static constexpr uint64_t c2 = 0x7a2b92ae912898c2L;

inline uint32_t hash32_1(uint64_t x) {
    uint32_t low = (uint32_t)x;
    uint32_t high = (uint32_t)(x >> 32);
    return (uint32_t)((a1 * low + b1 * high + c1) >> 32);
}
inline uint32_t hash32_2(uint64_t x) {
    uint32_t low = (uint32_t)x;
    uint32_t high = (uint32_t)(x >> 32);
    return (uint32_t)((a2 * low + b2 * high + c2) >> 32);
}

uint64_t hash64(uint64_t x) {
    uint32_t low = (uint32_t)x;
    uint32_t high = (uint32_t)(x >> 32);
    return ((a1 * low + b1 * high + c1) >> 32)
    | ((a2 * low + b2 * high + c2) & 0xFFFFFFFF00000000L);
}

// static uint64_t murmur64(uint64_t h) {
//     h ^= h >> 33;
//     h *= 0xff51afd7ed558ccdL;
//     h ^= h >> 33;
//     h *= 0xc4ceb9fe1a85ec53L;
//     h ^= h >> 33;
//     return h;
// }