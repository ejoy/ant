#include "psystem_manager.h"
#include <stdio.h>

#define MAX_P 1000
#define LIFE_TRANS 0
#define VALUE_TRANS 1

struct particle {
	float lifetime;
	int value;
};

struct life_transform {
	float lifetime;
};

struct value_transform {
	int value;
	int value_delta;
};

struct particles {
	int n;
	struct particle_manager *m;
	struct particle p[MAX_P];
	struct life_transform life[MAX_P];
	struct value_transform value[MAX_P];
	struct particle_transform_slice trans_slice[2];
};

static void
add_particle(struct particles *P, float lifetime) {
	particle_id id = particle_new(P->m);
	int index = particle_transform_add(P->m, id, LIFE_TRANS);
	P->life[index].lifetime = lifetime;
	P->trans_slice[LIFE_TRANS].n++;
	index = particle_transform_add(P->m, id, VALUE_TRANS);
	P->value[index].value = id;
	P->value[index].value_delta = 1;
	P->trans_slice[VALUE_TRANS].n++;
	++P->n;
}

static void
print(struct particles *P) {
	int i;
	printf("--------\n");
	for (i=0;i<P->n;i++) {
		printf("[%d] : ", i);
		printf("\tlife = %f", P->p[i].lifetime);
		printf("\tvalue = %d", P->p[i].value);
		printf("\n");
	}
}

static void
update_value(struct particles *P) {
	int i;
	const particle_id * id = particle_transform_id(P->m, VALUE_TRANS);
	for (i=0;i<P->trans_slice[VALUE_TRANS].n;i++) {
		int value = (P->value[i].value += P->value[i].value_delta);
		P->p[id[i]].value = value;
	}
}

static void
update_life(struct particles *P, float t) {
	int i;
	const particle_id * id = particle_transform_id(P->m, LIFE_TRANS);
	for (i=0;i<P->trans_slice[LIFE_TRANS].n;i++) {
		float life = (P->life[i].lifetime -= t);
		if (life <= 0) {
			particle_delete(P->m, id[i]);
		} else {
			P->p[id[i]].lifetime = life;
		}
	}
}

static void
update(struct particles *P, float t) {
	update_value(P);
	update_life(P, t);

	int removed = particle_arrange(P->m, P->p, sizeof(struct particle), P->trans_slice);
	if (removed) {
		P->n -= removed;
	}
	print(P);
}

static void
init(struct particles *P) {
	P->m = particle_create(2);
	P->trans_slice[LIFE_TRANS].ptr = &P->life;
	P->trans_slice[LIFE_TRANS].n = 0;
	P->trans_slice[LIFE_TRANS].size = sizeof(struct life_transform);

	P->trans_slice[VALUE_TRANS].ptr = &P->value;
	P->trans_slice[VALUE_TRANS].n = 0;
	P->trans_slice[VALUE_TRANS].size = sizeof(struct value_transform);
}


int
main() {
	struct particles P;
	init(&P);
	add_particle(&P, 10);
	add_particle(&P, 20);
	add_particle(&P, 15);

	update(&P, 5);
	update(&P, 5);

	return 0;
}
