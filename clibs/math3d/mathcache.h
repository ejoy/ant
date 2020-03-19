#ifndef math_cache_h
#define math_cache_h

struct math_key {
	int64_t srt;
	int64_t aabb;
};

struct math_value {
	float minmax[6];
	float mat[16];
};

struct math_cache_info {
	int hit;
	int miss;
	size_t memsize;
};

struct math_cache;

struct math_cache * mathcache_new();
void mathcache_delete(struct math_cache *C);
void mathcache_reset(struct math_cache *C);
int mathcache_lookup(struct math_cache *C, int64_t id, const struct math_key *key, struct math_value **value);
void mathcache_getinfo(struct math_cache *C, struct math_cache_info *info);

#endif
