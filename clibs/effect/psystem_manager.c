#include "psystem_manager.h"

#include <stdlib.h>
#include <string.h>
#include <assert.h>

struct particle_transform {
	int n;
	int cap;
	particle_id *id;
};

struct particle_manager {
	int n;
	int trans_n;
	particle_id removed_list_head;
	particle_id removed_list[MAX_PARTICLES];
	struct particle_transform trans[1];
};

static void
transform_init(struct particle_transform *trans) {
	trans->n = 0;
	trans->cap = 0;
	trans->id = NULL;
}

struct particle_manager *
particle_create(int transform_n) {
	size_t sz = sizeof(struct particle_manager) + (transform_n-1) * sizeof(struct particle_transform);
	struct particle_manager *m = (struct particle_manager *)malloc(sz);
	m->n = 0;
	m->trans_n = transform_n;
	m->removed_list_head = INVALID_PARTICLE;
	int i;
	for (i=0;i<MAX_PARTICLES;i++) {
		m->removed_list[i] = INVALID_PARTICLE;
	}
	for (i=0;i<transform_n;i++) {
		transform_init(&m->trans[i]);
	}
	return m;
}

void
particle_release(struct particle_manager *m) {
	if (m == NULL)
		return;
	int i;
	for (i=0;i<m->trans_n;i++) {
		free(m->trans[i].id);
	}
	free(m);
}

particle_id
particle_new(struct particle_manager *m) {
	if (m->n >= MAX_PARTICLES) {
		return INVALID_PARTICLE;
	} else {
		return m->n++;
	}
}

int
particle_transform_add(struct particle_manager *m, particle_id id, int transform_id) {
	assert(transform_id>=0 && transform_id<m->trans_n);
	struct particle_transform *trans = &m->trans[transform_id];
	if (trans->n >= trans->cap) {
		int newcap = trans->cap * 2;
		if (newcap == 0) {
			newcap = 32;
		}
		trans->id = (particle_id *)realloc(trans->id, sizeof(particle_id) * newcap);
		trans->cap = newcap;
	}
	int index = trans->n++;
	trans->id[index] = id;
	return index;
}

const particle_id *
particle_transform_id(struct particle_manager *m, int transform_id) {
	assert(transform_id>=0 && transform_id<m->trans_n);
	struct particle_transform *trans = &m->trans[transform_id];
	return trans->id;
}

void
particle_delete(struct particle_manager *m, particle_id id) {
	if (id < m->n) {
		if (m->removed_list_head == INVALID_PARTICLE) {
			// The first removed
			m->removed_list[id] = id;
		} else if (m->removed_list[id] == INVALID_PARTICLE) {
			m->removed_list[id] = m->removed_list_head;
		}
		m->removed_list_head = id;
	}
}

int
particle_arrange(struct particle_manager *m, void * particles, int particle_size, struct particle_transform_slice slices[]) {
	if (m->removed_list_head == INVALID_PARTICLE)
		return 0;
	particle_id map[MAX_PARTICLES];
	particle_id removed[MAX_PARTICLES];
	int i,j;
	for (i=0;i<m->n;i++) {
		map[i] = i;
	}
	particle_id removed_id = m->removed_list_head;
	int removed_n = 0;
	for (;;) {
		removed[removed_n++] = removed_id;
		// next removed
		particle_id next = m->removed_list[removed_id];
		m->removed_list[removed_id] = INVALID_PARTICLE;
		if (next == removed_id)
			break;
		removed_id = next;
	}
	// ascending sort removed[]
	for (i=0;i<removed_n-1;i++) {
		for (j=i+1;j<removed_n;j++) {
			if (removed[i] > removed[j]) {
				particle_id t = removed[i];
				removed[i] = removed[j];
				removed[j] = t;
			}
		}
	}

	int last = m->n - 1;
	int last_removed = removed_n - 1;

	for (i=0;i<removed_n;i++) {
		particle_id id = removed[i];
		map[id] = INVALID_PARTICLE;

		if (id < m->n - removed_n) {
			// find last, last_removed must be >= 0 because removed is sorted
			while (last == removed[last_removed]) {
				--last_removed;
				--last;
			}
		}
		// move slot 'last' to 'id'
		memcpy((char *)particles + particle_size * id, (char *)particles + particle_size * last, particle_size);
		map[last] = id;
		--last;
	}

	for (i=0;i<m->trans_n;i++) {
		struct particle_transform_slice *slice = &slices[i];
		struct particle_transform *t = &m->trans[i];
		int n = t->n;
		for (j=0;j<n;j++) {
			particle_id oldid = t->id[j];
			particle_id newid = map[oldid];
			if (newid != oldid) {
				--n;
				if (newid == INVALID_PARTICLE) {
					// removed
					t->id[j] = t->id[n];
					char * from_addr = (char *)slice->ptr + slice->size * n;
					char * to_addr = (char *)slice->ptr + slice->size * j;
					memcpy(to_addr, from_addr, slice->size);
					--j;
				} else {
					t->id[j] = newid;
				}
			}
		}
		t->n = n;
		slice->n = n;
	}
	return removed_n;
}
