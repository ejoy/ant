#include <string>
#include <vector>
#include <map>
#include <cassert>
#include <cstring>

std::vector<std::string>
split_string(const std::string &ss, char delim);

std::string&
refine_layout(std::string &elem);

std::vector<std::string>
split_layout_elems(const std::string &layout);

std::string
refine_layouts(std::string &layout);

struct data_buffer {
	uint32_t buffersize;
	uint8_t *data;
	data_buffer(uint32_t s = 0, bool clean = false)
		: buffersize(s) 
		, data(s != 0 ? new uint8_t[s] : nullptr){
		if (clean) {
			memset(data, 0, buffersize);
		}
	}
	
	data_buffer(data_buffer &&other) {
		data = other.data;
		buffersize = other.buffersize;
		other.data = nullptr;
		other.buffersize = 0;
	}

	~data_buffer() {
		if (data) {
			delete[]data;
			data = nullptr;
			buffersize = 0;
		}
	}

private:
	data_buffer(const data_buffer &);
	data_buffer& operator=(const data_buffer &);
};

using attrib_buffers = std::map<uint32_t, data_buffer>;

struct attrib_name {
	const char* name;
	const char* sname;
	uint32_t channel;
};

const uint32_t NUM_ATTIRBUTE_NAME = 20;
extern attrib_name attribname_mapper[NUM_ATTIRBUTE_NAME];

uint32_t
find_attrib_name(const std::string &elem);

uint32_t
find_attrib_name_by_fullname(const std::string &fullname);

void
calc_tangents(attrib_buffers &abuffers, uint32_t num_vertices, const data_buffer &indices, uint32_t num_indices);