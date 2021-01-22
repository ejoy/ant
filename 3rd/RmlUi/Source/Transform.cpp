#include "../Include/RmlUi/Transform.h"

namespace Rml {

UniquePtr<Transform> Transform::Interpolate(const Transform& other, float alpha) {
	if (size() != other.size()) {
		return {};
	}
	UniquePtr<Transform> new_transform(new Transform);
	new_transform->reserve(size());
	for (size_t i = 0; i < size(); ++i) {
		TransformPrimitive p = (*this)[i];
		if (!p.Interpolate(other[i], alpha)) {
			return {};
		}
		new_transform->emplace_back(std::move(p));
	}
	return new_transform;
}

}
