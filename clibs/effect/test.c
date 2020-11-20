#define PARTICLE_COMPONENT 3

#define COMPONENT_LIFE 0
#define COMPONENT_VALUE 1
#define TAG_PRINT 2	// virtual component, no attribs

static const char *COMPONENT_NAME[] = {
	"life",
	"value",
	"print",
};

#define REMAP_CACHE 4
#define MAX_P 16

#include "psystem_manager.h"
#include <stdio.h>

struct value {
	int value;
	int delta;
};

struct particles {
	struct particle_manager *m;
	int life_n;
	int value_n;
	float life[MAX_P];
	struct value value[MAX_P];
};

static void
add_particle(struct particles *P, float lifetime, int delta) {
	int c[PARTICLE_COMPONENT] = { TAG_PRINT, COMPONENT_LIFE, COMPONENT_VALUE };

	if (delta == 0) {
		// only add COMPONENT_LIFE
		if (particlesystem_add(P->m, 2, c)) {
			// add succ
			P->life[P->life_n++] = lifetime;
		}
	} else {
		if (particlesystem_add(P->m, 3, c)) {
			P->life[P->life_n++] = lifetime;
			struct value *v = &P->value[P->value_n++];
			v->value = 0;
			v->delta = delta;
		}
	}
}

static void
print_object(struct particles *P, int cid, int index) {
	int life_index = particlesystem_component(P->m, cid, index, COMPONENT_LIFE);
	if (life_index != PARTICLE_INVALID) {
		printf("\tlife = %f", P->life[life_index]);
	}
	int value_index = particlesystem_component(P->m, cid, index, COMPONENT_VALUE);
	if (value_index != PARTICLE_INVALID) {
		printf("\tvalue = %d", P->value[value_index].value);
	}
	printf("\n");
}

static void
print(struct particles *P) {
	int i;
	printf("Dump particles :\n");
	int n = particlesystem_count(P->m, TAG_PRINT);
	for (i=0;i<n;i++) {
		printf("\t[%d] : ", i);
		print_object(P, TAG_PRINT, i);
	}
}

static void
update_value(struct particles *P) {
	int i;
	for (i=0;i<P->value_n;i++) {
		struct value * v = &P->value[i];
		v->value += v->delta;
	}
}

static void
update_life(struct particles *P, float t) {
	// update life by life component
	int i;
	for (i=0;i<P->life_n;i++) {
		float life = (P->life[i] -= t);
		if (life <= 0) {
			particlesystem_remove(P->m, COMPONENT_LIFE, i);
		}
	}
}

static void
update(struct particles *P, float t) {
	update_value(P);
	update_life(P, t);

	struct particle_remap remap[REMAP_CACHE];
	struct particle_arrange_context ctx;
	int n = 0;
	int cap = sizeof(remap)/sizeof(remap[0]);
	do {
		n = particlesystem_arrange(P->m, cap, remap, &ctx);
		int i;
		for (i=0;i<n;i++) {
			switch(remap[i].component_id) {
			case COMPONENT_LIFE:
				if (remap[i].to_id != PARTICLE_INVALID) {
					printf("Remap life : %d to %d\n", remap[i].from_id, remap[i].to_id);
					P->life[remap[i].to_id] = P->life[remap[i].from_id];
				} else {
					printf("Resize life : %d to %d\n", P->life_n, remap[i].from_id);
					P->life_n = remap[i].from_id;
				}
				break;
			case COMPONENT_VALUE:
				if (remap[i].to_id != PARTICLE_INVALID) {
					P->value[remap[i].to_id] = P->value[remap[i].from_id];
					printf("Remap value : %d to %d\n", remap[i].from_id, remap[i].to_id);
				} else {
					printf("Resize value : %d to %d\n", P->value_n, remap[i].from_id);
					P->value_n = remap[i].from_id;
				}
				break;
			case TAG_PRINT:
				// ignore
				break;
			}
		}
	} while (n == cap);

	particlesystem_debug(P->m, COMPONENT_NAME);
	print(P);
}

static void
init(struct particles *P) {
	P->m = particlesystem_create();
	P->life_n = 0;
	P->value_n = 0;
}

int
main() {
	struct particles P;
	init(&P);
	add_particle(&P, 10, 0);
	add_particle(&P, 20, 1);
	add_particle(&P, 15, 10);
	add_particle(&P, 17, 3);
	add_particle(&P, 4, 5);
	add_particle(&P, 8, 20);

	int i;
	for (i=0;i<10;i++) {
		printf("== Frame %d ==\n", i);
		update(&P, 2);
	}

	particlesystem_release(P.m);

	return 0;
}
