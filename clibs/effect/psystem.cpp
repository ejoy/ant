#include "psystem.h"
#include <cstddef>
#include <cstdio>
#include <algorithm>
#include <vector>
#include "psystem_manager.h"
#define REMAP_CACHE 128

namespace {

template<typename T> struct type_ { static const int object_id; static const int pointer_id; };

#define PARTICLE_OBJECT_ID(T,ID) template<> const int type_<particle_system::T>::object_id = PID_##ID;

#define PARTICLE_POINTER_ID(T,ID) template<> const int type_<particle_system::T>::pointer_id = PID_##ID;

PARTICLE_OBJECT_ID(value, VALUE)
PARTICLE_OBJECT_ID(lifetime, LIFETIME)
PARTICLE_POINTER_ID(object, OBJECT)

}

class particle_system::attribute {
public:
	virtual ~attribute() {};
	virtual int remap(struct particle_remap *map, int n) = 0;
	virtual void pop_back() = 0;
};

namespace {
	template<typename T>
	struct attribute_remap : public particle_system::attribute {
		int remap(struct particle_remap *map, int n) override {
			T * self = static_cast<T *>(this);
			for (int i=0;i<n;i++) {
				if (map[i].component_id != map[0].component_id)
					return i;
				if (map[i].to_id != PARTICLE_INVALID) {
					self->move(map[i].from_id, map[i].to_id);
				} else {
					self->shrink(map[i].from_id);
				}
			}
		return n;
		}
	};

	template<typename T>
	struct attribute_object final : public attribute_remap<attribute_object<T>> {
		void move(int from, int to) {
			data[to] = std::move(data[from]);
		}
		void shrink(int n) {
			data.resize(n);
		}
		void pop_back() override {
			data.pop_back();
		}
		void* pointer(int index) {
			return reinterpret_cast<void *>(&data[index]);
		}
		std::vector<T> data;
	};

	template<typename T>
	struct attribute_pointer final : public attribute_remap<attribute_pointer<T>> {
		~attribute_pointer() {
			for (auto& iter : data) {
				delete(iter);
			}
		}
		void move(int from, int to) {
			delete(data[to]);
			data[to] = data[from];
			data[from] = nullptr;
		}
		void shrink(int n) {
			int sz = data.size();
			for (int i=n;i<sz;i++) {
				delete(data[i]);
			}
			data.resize(n);
		}
		void pop_back() override {
			delete(data.back());
			data.pop_back();
		}
		void* pointer(int index) {
			return reinterpret_cast<void *>(data[index]);
		}
		std::vector<T*> data;
	};
}

template<typename T>
struct particle_system::type : public type_<T> {
	static const int id = type_<T>::object_id;
	typedef attribute_object<T> container_type;
	typedef T value_type;
};

template <typename T>
struct particle_system::type<T*> : public type_<T> {
	static const int id = type_<T>::pointer_id;
	typedef attribute_pointer<T> container_type;
	typedef T value_type;
};

particle_system::particle_system() {
	manager = particlesystem_create();
	init<value>();
	init<lifetime>();
	init<object *>();
}

particle_system::~particle_system() {
	for (int i=0;i<maxid;i++) {
		delete attribs[i];
	}
	particlesystem_release(manager);
}

template <typename T>
void particle_system::init() {
	attribs[type<T>::id] = new typename type<T>::container_type;
}

template <typename T>
int particle_system::push_back(T &&v) {
	int id = type<T>::id;
	static_cast<typename type<T>::container_type *>(attribs[id])->data.push_back(v);
	return id;
}

template <typename T>
void particle_system::remove(int index) {
	particlesystem_remove(manager, type<T>::id, index);
}

template <typename T>
const typename particle_system::type<T>::value_type * particle_system::sibling(int tag, int index) {
	int sindex = particlesystem_component(manager, tag, index, type<T>::id);
	if (sindex == PARTICLE_INVALID)
		return nullptr;
	return reinterpret_cast<const typename type<T>::value_type *>
		(static_cast<typename type<T>::container_type *>(attribs[type<T>::id])->pointer(sindex));
}

void
particle_system::add(const std::initializer_list<int> &a) {
	if (!particlesystem_add(manager, a.size(), a.begin())) {
		for (auto id : a) {
			attribs[id]->pop_back();
		}
	}
}

template <typename T>
struct particle_system::container : public std::vector<T>, particle_system::type<T> {
	static particle_system::container<T>& convert(attribute *a) {
		return *static_cast<particle_system::container<T>*>(&static_cast<typename particle_system::type<T>::container_type *>(a)->data);
	}
};

template <typename T>
particle_system::container<T>& particle_system::attrib() {
	return container<T>::convert(attribs[container<T>::id]);
}

void
particle_system::arrange() {
	struct particle_remap remap[REMAP_CACHE];
	struct particle_arrange_context ctx;
	int n = 0;
	int cap = sizeof(remap)/sizeof(remap[0]);
	do {
		n = particlesystem_arrange(manager, cap, remap, &ctx);
		int i=0;
		while (i<n) {
			int component_id = remap[i].component_id;
			if (component_id < maxid) {
				i+=attribs[component_id]->remap(remap+i, n-i);
			} else {
				++i;
			}
		}
	} while (n == cap);
}

int
particle_system::size(int pid) {
	return particlesystem_count(manager, pid);
}

void
particle_system::update_life(float dt) {
	int index = 0;
	for (auto &life : attrib<lifetime>()) {
		printf("lifetime: %f\n", life);
		life -= dt;
		if (life <= 0) {
			printf("REMOVE %d\n", index);
			remove<lifetime>(index);
		}
		++index;
	}
}

void
particle_system::update_value() {
	for (auto &v : attrib<value>()) {
		v.value += v.delta;
	}
}

void
particle_system::update_print() {
	int n = size(TAG_PRINT);
	for (int i = 0;i<n;i++) {
		const value *v = sibling<value>(TAG_PRINT, i);
		if (v) {
			printf("Value = %d ", v->value);
		}
		const object *obj = sibling<object *>(TAG_PRINT, i);
		if (obj) {
			printf("Object = %d ", obj->value());
		}
		printf("\tParticle %d\n", i);
	}
}

void
particle_system::test() {
/*
	static const char *names[PARTICLE_COMPONENT] {
		"value",
		"lifetime",
		"object",
		"print",
	};
*/
	add({
		push_back(lifetime(10)),
		TAG_PRINT,
	});

	add({
		push_back(lifetime(20)),
		push_back(value { 0, 1 }),
		push_back(new object(42)),
		TAG_PRINT,
	});

	add({
		push_back(lifetime(15)),
		push_back(value { 0, 10 }),
		TAG_PRINT,
	});

	add({
		push_back(lifetime(17)),
		push_back(value { 0, 3 }),
		TAG_PRINT,
	});

	add({
		push_back(lifetime(4)),
		push_back(value { 0, 5 }),
		TAG_PRINT,
	});

	add({
		push_back(lifetime(8)),
		push_back(value { 0, 20 }),
		TAG_PRINT,
	});

	for (int i=0;i<10;i++) {
		printf("== Frame %d ==\n", i);
		update_life(2.0f);
		update_value();
		update_print();
//		particlesystem_debug(manager, names);
		arrange();
	}
}

int
main() {
	particle_system P;
	P.test();
	return 0;
}
