#ifndef particle_system_manager_h
#define particle_system_manager_h

#define PARTICLE_MAX 0xffff
#define PARTICLE_INVALID PARTICLE_MAX

#ifndef PARTICLE_COMPONENT
#define PARTICLE_COMPONENT 7
#endif

#ifndef PARTICLE_KEY_COMPONENT
#define PARTICLE_KEY_COMPONENT PARTICLE_COMPONENT
#endif

typedef unsigned short particle_index;

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

struct particle_remap {
	int component_id;
	particle_index from_id;
	particle_index to_id;
};

struct particle_arrange_context {
	int component;
	int index;
	int remove;
	particle_index map[PARTICLE_MAX];
};

struct particle {
	particle_index removed_list;
	particle_index c[PARTICLE_KEY_COMPONENT];
};

struct particle_ids {
	int n;
	int cap;
	particle_index *id;
};

struct particle_manager {
	int n;
	int cap;
	particle_index removed_head;
	unsigned char arranging;
	struct particle *p;
	struct particle_ids c[PARTICLE_COMPONENT];	// components
};

static inline void
particlesystem_ids_init_(struct particle_ids *ids) {
	ids->n = 0;
	ids->cap = 0;
	ids->id = NULL;
}

static inline void
particlesystem_ids_exit_(struct particle_ids *ids) {
	free(ids->id);
}

static inline struct particle_manager *
particlesystem_create() {
	struct particle_manager *P = (struct particle_manager *)malloc(sizeof(*P));
	P->n = 0;
	P->cap = 0;
	P->arranging = 0;
	P->removed_head = PARTICLE_INVALID;
	P->p = NULL;
	int i;
	for (i=0;i<PARTICLE_COMPONENT;i++) {
		particlesystem_ids_init_(&P->c[i]);
	}

	return P;
}

static inline void
particlesystem_release(struct particle_manager *P) {
	if (P == NULL)
		return;
	int i;
	for (i=0;i<PARTICLE_COMPONENT;i++) {
		particlesystem_ids_exit_(&P->c[i]);
	}
	free(P);
}

static inline particle_index
find_particle_(struct particle_manager *P, int component_id, particle_index index) {
	assert(component_id>=0 && component_id<PARTICLE_COMPONENT);
	assert(index>=0 && index<P->c[component_id].n);
	return P->c[component_id].id[index];
}

static inline int
particlesystem_count(struct particle_manager *P, int component_id) {
	assert(component_id>=0 && component_id<PARTICLE_COMPONENT);
	return P->c[component_id].n;
}

static inline particle_index
particlesystem_component(struct particle_manager *P, int component_id, particle_index index, int sibling_component_id) {
	particle_index pid = find_particle_(P, component_id, index);
	assert(sibling_component_id>=0 && sibling_component_id<PARTICLE_KEY_COMPONENT);
	return P->p[pid].c[sibling_component_id];
}

static inline particle_index
add_particle_(struct particle_manager *P) {
	if (P->n >= P->cap) {
		int newcap = P->cap * 2;
		if (newcap == 0) {
			newcap = 1024;
		}
		if (newcap > PARTICLE_MAX) {
			newcap = PARTICLE_MAX;
			if (P->n == PARTICLE_MAX)
				return PARTICLE_INVALID;
		}
		P->cap = newcap;
		P->p = (struct particle *)realloc(P->p, newcap * sizeof(struct particle));
	}
	particle_index index = (particle_index)P->n++;
	struct particle *p = &P->p[index];
	p->removed_list = PARTICLE_INVALID;
	int i;
	for (i=0;i<PARTICLE_KEY_COMPONENT;i++) {
		p->c[i] = PARTICLE_INVALID;
	}
	return index;
}

static inline particle_index
add_particle_ids_(struct particle_ids *ids, particle_index pid) {
	if (ids->n >= ids->cap) {
		int newcap = ids->cap * 2;
		if (newcap == 0) {
			newcap = 256;
		}
		if (newcap > PARTICLE_MAX) {
			newcap = PARTICLE_MAX;
			if (ids->n == PARTICLE_MAX)
				return PARTICLE_INVALID;
		}
		ids->cap = newcap;
		ids->id = (particle_index *)realloc(ids->id, sizeof(particle_index) * newcap);
	}
	particle_index index = (particle_index)ids->n++;
	ids->id[index] = pid;
	return index;
}

static inline int
particlesystem_add(struct particle_manager *P, int component_n, const int components[]) {
	particle_index pid = add_particle_(P);
	if (pid == PARTICLE_INVALID)
		return 0;
	struct particle *p = &P->p[pid];
	int i;
	for (i=0;i<component_n;i++) {
		int c = components[i];
		assert(c>=0 && c<PARTICLE_COMPONENT);
		particle_index index = add_particle_ids_(&P->c[c], pid);
		// make key index
		if (c < PARTICLE_KEY_COMPONENT)
			p->c[c] = index;
	}
	return 1;
}

static inline void
particlesystem_remove_(struct particle_manager *P, particle_index pid) {
	assert(pid >= 0 && pid < P->n);
	if (P->p[pid].removed_list != PARTICLE_INVALID) {
		// already removed
		return;
	}
	if (P->removed_head == PARTICLE_INVALID) {
		// the first removed
		P->p[pid].removed_list = pid;
	} else {
		P->p[pid].removed_list = P->removed_head;
	}
	P->removed_head = pid;
}

static inline void
particlesystem_remove(struct particle_manager *P, int component_id, particle_index index) {
	particle_index pid = find_particle_(P, component_id, index);
	particlesystem_remove_(P, pid);
}

static inline int
compar_particle_index_(const void *a, const void *b) {
	const particle_index *aa = (const particle_index *)a;
	const particle_index *bb = (const particle_index *)b;
	return *aa - *bb;
}

static inline void
arrange_init_(struct particle_manager *P, struct particle_arrange_context *ctx) {
	int i;
	for (i=0;i<P->n;i++) {
		ctx->map[i] = i;
	}
	particle_index removed_id = P->removed_head;
	int removed_n = 0;
	particle_index removed[PARTICLE_MAX];
	for (;;) {
		removed[removed_n++] = removed_id;
		// next removed
		particle_index next = P->p[removed_id].removed_list;
		P->p[removed_id].removed_list = PARTICLE_INVALID;
		if (next == removed_id)
			break;
		removed_id = next;
	}
	qsort(removed, removed_n, sizeof(particle_index), compar_particle_index_);

	int last = P->n - 1;
	int last_removed = removed_n - 1;

	for (i=0;i<removed_n;i++) {
		particle_index id = removed[i];
		ctx->map[id] = PARTICLE_INVALID;

		if (id < P->n - removed_n) {
			// find last, last_removed must be >= 0 because removed is sorted
			while (last == removed[last_removed]) {
				--last_removed;
				--last;
			}
		}

		if (id < last) {
			// move slot 'last' to 'id'
			P->p[id] = P->p[last];
			ctx->map[last] = id;
		}
		--last;
	}

	P->n = last+1;
	P->arranging = 1;
	ctx->component = 0;
	ctx->index = 0;
	ctx->remove = 0;
}

static inline int
arrange_component_(struct particle_manager *P, int cap, struct particle_remap remap[], struct particle_arrange_context *ctx) {
	int i,j;
	int ret_index = 0;
	for (i=ctx->component;i<PARTICLE_COMPONENT;i++) {
		struct particle_ids *c = &P->c[i];
		particle_index *ids = c->id;
		for (j=ctx->index;j<c->n;j++) {
			if (ret_index >= cap) {
				ctx->component = i;
				ctx->index = j;
				return ret_index;
			}
			particle_index oldid = ids[j];
			particle_index newid = ctx->map[oldid];
			if (newid != oldid) {
				if (newid == PARTICLE_INVALID) {
					// removed
					--c->n;
					if (j<c->n) {
						particle_index pid  = ids[c->n];
						ids[j] = pid;
						remap[ret_index].component_id = i;
						remap[ret_index].from_id = c->n;
						remap[ret_index].to_id = j;
						if (i < PARTICLE_KEY_COMPONENT) {
							P->p[pid].c[i] = j;
						}
						++ret_index;
					}
					--j;
					++ctx->remove;
				} else {
					ids[j] = newid;
				}
			}
		}
		if (ctx->remove) {
			if (ret_index >= cap) {
				ctx->component = i;
				ctx->index = j;
				return ret_index;
			}
			remap[ret_index].component_id = i;
			remap[ret_index].from_id = c->n;
			remap[ret_index].to_id = PARTICLE_INVALID;	// resize
			++ret_index;
		}
		ctx->index = 0;
		ctx->remove = 0;
	}
	if (ret_index >= cap) {
		ctx->component = i;
		ctx->index = 0;
	} else {
		P->arranging = 0;
		P->removed_head = PARTICLE_INVALID;
	}
	return ret_index;
}

static inline int
particlesystem_arrange(struct particle_manager *P, int cap, struct particle_remap remap[], struct particle_arrange_context *ctx) {
	if (P->removed_head == PARTICLE_INVALID) {
		return 0;
	}
	if (P->arranging == 0) {
		arrange_init_(P, ctx);
	}
	return arrange_component_(P, cap, remap, ctx);
}

static inline void
particlesystem_debug(struct particle_manager *P, const char **cname) {
	int i,j;
	printf("particles %d\n", P->n);
	for (i=0;i<P->n;i++) {
		struct particle *p = &P->p[i];
		printf("\t[P%d] :", i);
		for (j=0;j<PARTICLE_KEY_COMPONENT;j++) {
			if (p->c[j] != PARTICLE_INVALID) {
				if (cname) {
					printf(" %s:%d", cname[j],p->c[j]);
				} else {
					printf(" C%d:%d", j,p->c[j]);
				}
			}
		}
		if (p->removed_list != PARTICLE_INVALID) {
			printf(" [RM]");
		}
		printf("\n");
	}
	for (i=0;i<PARTICLE_COMPONENT;i++) {
		if (cname) {
			printf("[%s] :", cname[i]);
		} else {
			printf("component [%d] :", i);
		}
		for (j=0;j<P->c[i].n;j++) {
			printf(" %d", P->c[i].id[j]);
		}
		printf("\n");
	}
}

#endif