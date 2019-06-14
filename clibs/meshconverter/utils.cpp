#include "utils.h"
#include "glm/glm.hpp"

#include <sstream>
#include <iostream>

std::vector<std::string>
split_string(const std::string &ss, char delim) {
	std::istringstream iss(ss);
	std::vector<std::string> vv;
	std::string elem;
	while (std::getline(iss, elem, delim)) {
		vv.push_back(elem);
	}

	return vv;
}

const char* s_default_layout = "_30NIf";

std::string&
refine_layout(std::string &elem) {
	assert(!elem.empty());
	if (elem.size() < 6) {
		elem += s_default_layout + elem.size();
	}

	return elem;
}

std::vector<std::string>
split_layout_elems(const std::string &layout) {
	auto elems = split_string(layout, '|');
	for (auto &e : elems) {
		refine_layout(e);
	}

	return elems;
}

std::string
refine_layouts(std::string &layout) {
	auto elems = split_layout_elems(layout);
	
	std::string fulllayout;
	for (const auto &e : elems){
		if (!fulllayout.empty()) {
			fulllayout += "|";
		}
		fulllayout += e;
	}
	return fulllayout;
}

attrib_name attribname_mapper[NUM_ATTIRBUTE_NAME] = {
	{"POSITION", "p", 0},

	{"NORMAL", "n", 0},
	{"TANGENT", "T", 0},
	{"BITANGENT", "b", 0},

	{"COLOR_0", "c", 0},
	{"COLOR_1", "c", 1},
	{"COLOR_2", "c", 2},
	{"COLOR_3",	"c", 3 },

	{ "TEXCOORD_0", "t", 0 },
	{ "TEXCOORD_1", "t", 1 },
	{ "TEXCOORD_2", "t", 2 },
	{ "TEXCOORD_3", "t", 3 },
	{ "TEXCOORD_4", "t", 4 },
	{ "TEXCOORD_5", "t", 5 },
	{ "TEXCOORD_6", "t", 6 },
	{ "TEXCOORD_7", "t", 7 },

	{"WEIGHT_0", "w", 0},
	{"WEIGHT_1", "w", 1},

	{"JOINTS_0", "i", 0},
	{"JOINTS_1", "i", 1},
};

uint32_t
find_attrib_name(const std::string &elem) {
	const char et = elem[0];
	const uint8_t channel = elem[2] - '0';
	for (uint32_t attribname = 0; attribname < NUM_ATTIRBUTE_NAME; ++attribname) {
		const auto& a = attribname_mapper[attribname];

		if (a.sname[0] == et && a.channel == channel) {
			return attribname;
		}
	}

	return NUM_ATTIRBUTE_NAME;
}

uint32_t 
find_attrib_name_by_fullname(const std::string &fullname) {
	for (uint32_t attribname = 0; attribname < NUM_ATTIRBUTE_NAME; ++attribname) {
		const auto& a = attribname_mapper[attribname];

		if (a.name == fullname) {
			return attribname;
		}
	}

	return NUM_ATTIRBUTE_NAME;
}

void 
calc_tangents(attrib_buffers &abuffers, uint32_t num_vertices, const data_buffer &indices, uint32_t num_indices) {
	data_buffer tangents(sizeof(glm::vec4) * num_vertices, true),
		bitangents(sizeof(glm::vec3) * num_vertices, true);

	auto getbuffer = [](attrib_buffers &abuffers, const std::string& name) {
		auto ittex = abuffers.find(find_attrib_name_by_fullname(name));
		return ittex == abuffers.end() ? (data_buffer*)nullptr : &(ittex->second);
	};
		
	const data_buffer *positions = getbuffer(abuffers, "POSITION");
	const data_buffer *texcoord0 = getbuffer(abuffers, "TEXCOORD_0");
	const data_buffer* normals = getbuffer(abuffers, "NORMAL");
	
	assert(num_vertices < std::numeric_limits<uint16_t>::max());

	for (uint32_t ii = 0, num = num_indices / 3; ii < num; ++ii) {
		const uint16_t* indicesdata = (const uint16_t*)indices.data + ii * 3;

		const uint32_t tri_indices[] = { indicesdata[0], indicesdata[1], indicesdata[2] };

		const glm::vec3* posdata = (const glm::vec3*)positions->data;
		const glm::vec2 *texcoord0data = (const glm::vec2*)texcoord0->data;

		const glm::vec3 pos_ba = posdata[tri_indices[1]] - posdata[tri_indices[0]];
		const glm::vec2 tex_ba = texcoord0data[tri_indices[1]] - texcoord0data[tri_indices[0]];

		const glm::vec3 pos_ca = posdata[tri_indices[2]] - posdata[tri_indices[0]];
		const glm::vec2 tex_ca = texcoord0data[tri_indices[2]] - texcoord0data[tri_indices[0]];

		const float det = tex_ba.x * tex_ca.y - tex_ba.y * tex_ca.x;
		const float inv_det = 1.f / det;

		const glm::vec3 tangent = (pos_ba * tex_ca.y - pos_ca * tex_ba.y) * inv_det;
		const glm::vec3 bitangent = (pos_ca * tex_ba.x - pos_ba * tex_ca.x) * inv_det;

		glm::vec4* tangentdata = (glm::vec4*)tangents.data;
		glm::vec3* bitangentdata = (glm::vec3*)bitangents.data;

		for (auto idx : tri_indices) {
			glm::vec3& t = *(glm::vec3*)((glm::vec4*)tangentdata + idx);
			t += tangent;
			bitangentdata[idx] += bitangent;
		}
	}

	const auto tangentname = find_attrib_name_by_fullname("TANGENT");
	const auto bitangentname = find_attrib_name_by_fullname("BITANGENT");

	for (uint32_t iv = 0; iv < num_vertices; ++iv) {
		glm::vec4* t = (glm::vec4*)tangents.data + iv;
		glm::vec3* b = (glm::vec3*)bitangents.data + iv;

		glm::vec3* t3 = (glm::vec3*)t;

		const glm::vec3 *n = (const glm::vec3*)normals->data;

		const float tdotn = glm::dot(*t3, *n);
		const glm::vec3 tt = *t3 - tdotn * *n;

		glm::vec3 tmp = glm::cross(*n, *t3);
		const float sign = glm::dot(tmp, *b) > 0 ? 1.f : -1.f;

		*t = glm::vec4(glm::normalize(tt), sign);
		*b = glm::cross(*n, tt);
	}

	if (getbuffer(abuffers, "TANGENT") == nullptr) {
		abuffers.insert(std::make_pair(tangentname, std::move(tangents)));
	}

	if (getbuffer(abuffers, "BITANGENT") == nullptr) {
		abuffers.insert(std::make_pair(bitangentname, std::move(bitangents)));
	}	
}

