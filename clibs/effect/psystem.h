#ifndef particle_system_h
#define particle_system_h

#define	PID_VALUE 0
#define PID_OBJECT 1

#define PARTICLE_KEY_COMPONENT 2	// key components 

#define PID_LIFETIME 2

#define PID_COUNT 3	// number components types of data in particle_system

#define TAG_PRINT 3
#define PARTICLE_COMPONENT 4	// total tags and components

#include <initializer_list>

struct particle_manager;

class particle_system {
public:
	struct value {
		int value;
		int delta;
	};
	class object {
	public:
		object(int v) : v(v) {}
		int value() const { return v; }
	private:
		int v;
	};
	typedef float lifetime;

	particle_system();
	~particle_system();
	void test();
	void update_life(float dt);
	void update_value();
	void update_print();
	static const int maxid = PID_COUNT;
private:
	template <typename T> struct type;

	void arrange();
	void add(const std::initializer_list<int> &a);

	template <typename T> void init();
	template <typename T> int push_back(T &&);
	template <typename T> void pop_back();
	template <typename T> void remove(int index);
	template <typename T> struct container;
	template <typename T> const typename type<T>::value_type * sibling(int tag, int index);
	template <typename T> container<T>& attrib();
	int size(int pid);

	class attribute;
	attribute * attribs[maxid];
	struct particle_manager *manager;
};

#endif
