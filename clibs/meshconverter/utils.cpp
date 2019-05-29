#include "utils.h"

#include <sstream>

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

std::string
GetDefaultVertexLayoutElem() {
	return s_default_layout;
}

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

std::string GenStreamNameFromElem(const std::string &elem){
	std::string ss;
	ss += elem[0];

	if (elem[0] == 't' || elem[2] == 'c') {
		ss += elem[2];
	}

	return ss;
}


//void 
//calc_tangent(const uint16_t* indices, const float* vertices, const float *uv, 
//	std::vector<glm::vec3> &tangents, std::vector<glm::vec3> &binormals) {
//
//}