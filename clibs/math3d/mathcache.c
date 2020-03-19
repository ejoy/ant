#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "mathcache.h"

#define HASHID(C, id) (((uint64_t)id) % ((C)->hashsize - 1))
#define MINHASHSIZE 1024

struct math_data {
	struct math_key key;
	struct math_value value;
};

struct math_data_node {
	struct math_data_node *next;
	struct math_data kv;
};

// 64K per page
#define PAGESLOT ((64 * 1024 - 16) / sizeof(struct math_data_node))

struct math_data_page {
	struct math_data_page *nextpage;
	struct math_data_node *node;
};

struct math_cache_node {
	int64_t id;
	struct math_data_node *node;
};

struct math_cache {
	struct math_cache_node * hash;
	struct math_data_page * data;
	struct math_data_node * freenode;
	int64_t lastid;
	struct math_data_node ** lastnode;
	int hashsize;
	int count;
	struct math_cache_info info;
};

static inline void *
cache_malloc(struct math_cache *C, size_t newsize) {
	C->info.memsize += newsize;
	return malloc(newsize);
}

static inline void
cache_mfree(struct math_cache *C, void *oldptr, size_t oldsize) {
	free(oldptr);
	C->info.memsize -= oldsize;
}

static struct math_data_page *
newpage(struct math_cache *C) {
	struct math_data_page *page = cache_malloc(C, sizeof(struct math_data_page));
	if (page == NULL)
		return NULL;
	page->nextpage = NULL;
	page->node = cache_malloc(C, PAGESLOT * sizeof(struct math_data_node));
	if (page->node == NULL) {
		cache_mfree(C, page, sizeof(struct math_data_page));
		return NULL;
	}
	int i;	
	for (i=0;i<PAGESLOT-1;i++) {
		page->node[i].next = &page->node[i+1];
	}
	page->node[PAGESLOT-1].next = NULL;
	return page;
}

static int
init(struct math_cache *C) {
	size_t sz = C->hashsize * sizeof(struct math_cache_node);
	C->hash = cache_malloc(C, sz);
	if (C->hash == NULL)
		return 0;
	memset(C->hash, 0, sz);
	C->data = newpage(C);
	if (C->data == NULL)
		return 0;
	C->freenode = C->data->node;
	C->lastid = 0;
	C->lastnode = NULL;
	C->count = 0;
	C->info.hit = 0;
	C->info.miss = 0;
	return 1;	// succ
}

static void
freepage(struct math_cache *C, struct math_data_page *page) {
	if (page) {
		cache_mfree(C, page->node, PAGESLOT * sizeof(struct math_data_node));
		struct math_data_page *nextpage = page->nextpage;
		cache_mfree(C, page, sizeof(struct math_data_page));
		freepage(C, nextpage);
	}
}

static void
deinit(struct math_cache *C) {
	cache_mfree(C, C->hash, C->hashsize * sizeof(struct math_cache_node));
	C->hash = NULL;
	freepage(C, C->data);
	C->data = NULL;
	C->freenode = NULL;
}

struct math_cache *
mathcache_new() {
	struct math_cache tmp;
	tmp.hash = NULL;
	tmp.data = NULL;
	tmp.freenode = NULL;
	tmp.hashsize = MINHASHSIZE;
	tmp.info.memsize = 0;
	if (!init(&tmp)) {
		// failed
		deinit(&tmp);
		return NULL;
	}
	struct math_cache * result = cache_malloc(&tmp, sizeof(struct math_cache));
	if (result) {
		memcpy(result, &tmp, sizeof(tmp));
	}
	return result;
}

void
mathcache_delete(struct math_cache *C) {
	deinit(C);
	struct math_cache tmp;
	tmp.info.memsize = C->info.memsize;
	cache_mfree(&tmp, C, sizeof(struct math_cache));
}

static struct math_data_node *
allocnode(struct math_cache *C) {
	struct math_data_node *node = C->freenode;
	if (node) {
		C->freenode = node->next;
	} else {
		struct math_data_page *page = newpage(C);
		if (page == NULL)
			return NULL;
		page->nextpage = C->data;
		node = page->node;
		C->freenode = page->node->next;
	}
	node->next = NULL;
	return node;
}

static void
freelist(struct math_cache *C, struct math_data_node *node) {
	if (node == NULL)
		return;
	struct math_data_node *last = node;
	while (last->next) {
		last = last->next;
	}
	last->next = C->freenode;
	C->freenode = node;
}

static void
resize(struct math_cache *C, int newsize) {
	if (C->hashsize == newsize || newsize <= 0)
		return;
	size_t sz = newsize * sizeof(struct math_cache_node);
	struct math_cache_node *newhash = cache_malloc(C, sz);
	if (newhash == NULL)
		return;
	memset(newhash, 0, sz);
	int oldsize = C->hashsize;
	struct math_cache_node *oldhash = C->hash;
	C->hash = newhash;
	C->hashsize = newsize;
	int i;
	for (i=0;i<oldsize;i++) {
		int64_t id = oldhash[i].id;
		int idx = HASHID(C, id);
		if (newhash[idx].id == 0) {
			newhash[idx].id = id;
			newhash[idx].node = oldhash[i].node;
		} else {
			freelist(C, oldhash[i].node);
		}
	}
	cache_mfree(C, oldhash, oldsize * sizeof(struct math_cache_node));
}

void
mathcache_reset(struct math_cache *C) {
	if (C->count > C->hashsize) {
		int newsize = C->hashsize * 2;
		while (newsize < C->count) {
			newsize *= 2;
		}
		resize(C, newsize);
	} else if (C->count * 2 < C->hashsize && C->hashsize > MINHASHSIZE) {
		resize(C, C->hashsize / 2);
	}
	C->lastid = 0;
	C->lastnode = NULL;
	C->count = 0;
	C->info.hit = 0;
	C->info.miss = 0;
}

static int
set_node(struct math_cache *C, struct math_data_node *node, const struct math_key *key, struct math_value **value) {
	node->kv.key = *key;
	C->lastnode = &node->next;
	*value = &node->kv.value;
	++C->info.miss;
	return 1;
}

// returns 0 : cache hit, *value is the result
// returns 1 : cache miss, you can modify the *value
int
mathcache_lookup(struct math_cache *C, int64_t id, const struct math_key *key, struct math_value **value) {
	assert(id != 0);
	if (id == C->lastid) {
		struct math_data_node * node = *C->lastnode;
		if (node == NULL) {
			// no next one in the list, alloc a new node
			node = allocnode(C);
			if (node == NULL) {
				// out of memory
				*value = NULL;
				return 1;
			}
			*C->lastnode = node;
			return set_node(C, node, key, value);
		} else if (memcmp(key, &node->kv.key, sizeof(*key))==0) {
			// cache hit
			C->lastnode = &node->next;
			*value = &node->kv.value;
			++C->info.hit;
			return 0;
		} else {
			// cache miss
			freelist(C, node->next);
			node->next = NULL;
			return set_node(C, node, key, value);
		}
	} else {
		// cache miss
		C->lastid = id;
		++C->count;
		int idx = HASHID(C, id);
		struct math_cache_node *cachenode = &C->hash[idx];
		if (cachenode->id != id) {
			// cache collide
			struct math_data_node * node = allocnode(C);
			if (node == NULL) {
				// out of memory
				*value = NULL;
				return 1;
			}
			cachenode->id = id;
			freelist(C, cachenode->node);
			cachenode->node = node;
			return set_node(C, node, key, value);
		} else {
			struct math_data_node * node = cachenode->node;
			if (memcmp(key, &node->kv.key, sizeof(*key))==0) {
				// cache hit
				C->lastnode = &node->next;
				*value = &node->kv.value;
				++C->info.hit;
				return 0;
			} else {
				// cache miss
				node = allocnode(C);
				if (node == NULL) {
					// out of memory
					*value = NULL;
					return 1;
				}
				freelist(C, node);
				cachenode->node = node;
				return set_node(C, node, key, value);
			}
		}
	}
}

void
mathcache_getinfo(struct math_cache *C, struct math_cache_info *info) {
	*info = C->info;
}
