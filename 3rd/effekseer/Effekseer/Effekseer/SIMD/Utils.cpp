#include "Utils.h"
#include "../Effekseer.InternalStruct.h"
#include "../Effekseer.Vector2D.h"
#include "../Effekseer.Vector3D.h"
#include "Vec2f.h"
#include "Vec3f.h"
#include "Vec4f.h"

namespace Effekseer
{

namespace SIMD
{

//----------------------------------------------------------------------------------
// Temporary implementation
//----------------------------------------------------------------------------------
Vec2f::Vec2f(const vector2d& vec)
	: s(vec.x, vec.y, 0.0f, 0.0f)
{
}

Vec2f::Vec2f(const Vector2D& vec)
	: s(vec.X, vec.Y, 0.0f, 0.0f)
{
}

Vec3f::Vec3f(const vector3d& vec)
	: s(vec.x, vec.y, vec.z, 0.0f)
{
}

Vec3f::Vec3f(const Vector3D& vec)
	: s(vec.X, vec.Y, vec.Z, 0.0f)
{
}

Vec3f::Vec3f(const std::array<float, 3>& vec)
	: s(vec[0], vec[1], vec[2], 0.0f)
{
}

} // namespace SIMD

} // namespace Effekseer
