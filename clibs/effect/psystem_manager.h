#ifndef particle_system_manager_h
#define particle_system_manager_h

typedef unsigned short particle_id;

#define MAX_PARTICLES 0xffff
#define INVALID_PARTICLE MAX_PARTICLES

struct particle_manager;
struct particle_transform_slice {
	void *ptr;
	int n;
	int size;
};

struct particle_manager * particle_create(int transform_n);
void particle_release(struct particle_manager *m);
particle_id particle_new(struct particle_manager *m);
int particle_transform_add(struct particle_manager *m, particle_id id, int transform_id);
const particle_id * particle_transform_id(struct particle_manager *m, int transform_id);
void particle_delete(struct particle_manager *m, particle_id id);
int particle_arrange(struct particle_manager *m, void * particles, int particle_size, struct particle_transform_slice slices[]);

#endif
