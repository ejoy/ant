

#include "EffekseerRenderer.CommonUtils.h"

namespace EffekseerRenderer
{

void CalcBillboard(::Effekseer::BillboardType billboardType,
				   Effekseer::SIMD::Mat43f& dst,
				   ::Effekseer::SIMD::Vec3f& s,
				   ::Effekseer::SIMD::Vec3f& R,
				   ::Effekseer::SIMD::Vec3f& F,
				   const ::Effekseer::SIMD::Mat43f& src,
				   const ::Effekseer::SIMD::Vec3f& frontDirection)
{
	auto frontDir = frontDirection;

	if (billboardType == ::Effekseer::BillboardType::Billboard || billboardType == ::Effekseer::BillboardType::RotatedBillboard ||
		billboardType == ::Effekseer::BillboardType::YAxisFixed)
	{
		::Effekseer::SIMD::Mat43f r;
		::Effekseer::SIMD::Vec3f t;
		src.GetSRT(s, r, t);

		::Effekseer::SIMD::Vec3f U;

		if (billboardType == ::Effekseer::BillboardType::Billboard)
		{
			::Effekseer::SIMD::Vec3f Up(0.0f, 1.0f, 0.0f);

			F = frontDir;
			R = ::Effekseer::SIMD::Vec3f::Cross(Up, F).Normalize();
			U = ::Effekseer::SIMD::Vec3f::Cross(F, R).Normalize();
		}
		else if (billboardType == ::Effekseer::BillboardType::RotatedBillboard)
		{
			::Effekseer::SIMD::Vec3f Up(0.0f, 1.0f, 0.0f);

			F = frontDir;
			R = ::Effekseer::SIMD::Vec3f::Cross(Up, F).Normalize();
			U = ::Effekseer::SIMD::Vec3f::Cross(F, R).Normalize();

			float c_zx2 = Effekseer::SIMD::Vec3f::Dot(r.Y, r.Y) - r.Y.GetZ() * r.Y.GetZ();
			float c_zx = sqrt(std::max(0.0f, c_zx2));
			float s_z = 0.0f;
			float c_z = 0.0f;

			if (fabsf(c_zx) > 0.001f)
			{
				s_z = r.Y.GetX() / c_zx;
				c_z = r.Y.GetY() / c_zx;
			}
			else
			{
				s_z = 0.0f;
				c_z = 1.0f;
			}

			::Effekseer::SIMD::Vec3f r_temp = R;
			::Effekseer::SIMD::Vec3f u_temp = U;

			R = r_temp * c_z + u_temp * s_z;
			U = u_temp * c_z - r_temp * s_z;
		}
		else if (billboardType == ::Effekseer::BillboardType::YAxisFixed)
		{
			U = ::Effekseer::SIMD::Vec3f(r.X.GetY(), r.Y.GetY(), r.Z.GetY());
			F = frontDir;
			R = ::Effekseer::SIMD::Vec3f::Cross(U, F).Normalize();
			F = ::Effekseer::SIMD::Vec3f::Cross(R, U).Normalize();
		}

		dst.X = {R.GetX(), U.GetX(), F.GetX(), t.GetX()};
		dst.Y = {R.GetY(), U.GetY(), F.GetY(), t.GetY()};
		dst.Z = {R.GetZ(), U.GetZ(), F.GetZ(), t.GetZ()};
	}
}

static void FastScale(::Effekseer::SIMD::Mat43f& mat, float scale)
{
	float x = mat.X.GetW();
	float y = mat.Y.GetW();
	float z = mat.Z.GetW();

	mat.X *= scale;
	mat.Y *= scale;
	mat.Z *= scale;

	mat.X.SetW(x);
	mat.Y.SetW(y);
	mat.Z.SetW(z);
}

static void FastScale(::Effekseer::SIMD::Mat44f& mat, float scale)
{
	float x = mat.X.GetW();
	float y = mat.Y.GetW();
	float z = mat.Z.GetW();

	mat.X *= scale;
	mat.Y *= scale;
	mat.Z *= scale;

	mat.X.SetW(x);
	mat.Y.SetW(y);
	mat.Z.SetW(z);
}

void ApplyDepthParameters(::Effekseer::SIMD::Mat43f& mat,
						  const ::Effekseer::SIMD::Vec3f& cameraFront,
						  const ::Effekseer::SIMD::Vec3f& cameraPos,
						  ::Effekseer::NodeRendererDepthParameter* depthParameter,
						  bool isRightHand)
{
	auto depthOffset = depthParameter->DepthOffset;
	auto isDepthOffsetScaledWithCamera = depthParameter->IsDepthOffsetScaledWithCamera;
	auto isDepthOffsetScaledWithEffect = depthParameter->IsDepthOffsetScaledWithParticleScale;

	if (depthOffset != 0)
	{
		auto offset = depthOffset;

		if (isDepthOffsetScaledWithEffect)
		{
			auto scales = mat.GetScale();
			auto scale = (scales.GetX() + scales.GetY() + scales.GetZ()) / 3.0f;

			offset *= scale;
		}

		if (isDepthOffsetScaledWithCamera)
		{
			auto t = mat.GetTranslation();
			auto c = t - cameraPos;
			auto cl = c.GetLength();

			if (cl != 0.0)
			{
				auto scale = (cl - offset) / cl;
				FastScale(mat, scale);
			}
		}

		auto objPos = mat.GetTranslation();
		auto dir = cameraPos - objPos;
		dir = dir.Normalize();

		if (isRightHand)
		{
			mat.SetTranslation(mat.GetTranslation() + dir * offset);
		}
		else
		{
			mat.SetTranslation(mat.GetTranslation() + dir * offset);
		}
	}

	if (depthParameter->SuppressionOfScalingByDepth < 1.0f)
	{
		auto t = mat.GetTranslation();
		auto c = t - cameraPos;
		auto cl = c.GetLength();
		// auto cl = cameraFront.X * cx + cameraFront.Y * cy * cameraFront.Z * cz;

		if (cl != 0.0)
		{
			auto scale = cl / 32.0f * (1.0f - depthParameter->SuppressionOfScalingByDepth) + depthParameter->SuppressionOfScalingByDepth;
			FastScale(mat, scale);
		}
	}
}

void ApplyDepthParameters(::Effekseer::SIMD::Mat43f& mat,
						  ::Effekseer::SIMD::Vec3f& translationValues,
						  ::Effekseer::SIMD::Vec3f& scaleValues,
						  const ::Effekseer::SIMD::Vec3f& cameraFront,
						  const ::Effekseer::SIMD::Vec3f& cameraPos,
						  ::Effekseer::NodeRendererDepthParameter* depthParameter,
						  bool isRightHand)
{
	auto depthOffset = depthParameter->DepthOffset;
	auto isDepthOffsetScaledWithCamera = depthParameter->IsDepthOffsetScaledWithCamera;
	auto isDepthOffsetScaledWithEffect = depthParameter->IsDepthOffsetScaledWithParticleScale;

	if (depthOffset != 0)
	{
		auto offset = depthOffset;

		if (isDepthOffsetScaledWithEffect)
		{
			auto scale = (scaleValues.GetX() + scaleValues.GetY() + scaleValues.GetZ()) / 3.0f;
			offset *= scale;
		}

		if (isDepthOffsetScaledWithCamera)
		{
			auto c = translationValues - cameraPos;
			auto cl = c.GetLength();

			if (cl != 0.0)
			{
				auto scale = (cl - offset) / cl;

				scaleValues *= scale;
			}
		}

		auto objPos = translationValues;
		auto dir = cameraPos - objPos;
		dir = dir.Normalize();

		if (isRightHand)
		{
			translationValues += dir * offset;
		}
		else
		{
			translationValues += dir * offset;
		}
	}

	if (depthParameter->SuppressionOfScalingByDepth < 1.0f)
	{
		auto cam2t = translationValues - cameraPos;
		auto cl = cam2t.GetLength();

		if (cl != 0.0)
		{
			auto scale = cl / 32.0f * (1.0f - depthParameter->SuppressionOfScalingByDepth) + depthParameter->SuppressionOfScalingByDepth;
			for (auto r = 0; r < 3; r++)
			{
				for (auto c = 0; c < 3; c++)
				{
					scaleValues *= scale;
				}
			}
		}
	}
}

void ApplyDepthParameters(::Effekseer::SIMD::Mat43f& mat,
						  const ::Effekseer::SIMD::Vec3f& cameraFront,
						  const ::Effekseer::SIMD::Vec3f& cameraPos,
						  ::Effekseer::SIMD::Vec3f& scaleValues,
						  ::Effekseer::NodeRendererDepthParameter* depthParameter,
						  bool isRightHand)
{
	auto depthOffset = depthParameter->DepthOffset;
	auto isDepthOffsetScaledWithCamera = depthParameter->IsDepthOffsetScaledWithCamera;
	auto isDepthOffsetScaledWithEffect = depthParameter->IsDepthOffsetScaledWithParticleScale;

	if (depthOffset != 0)
	{
		auto offset = depthOffset;

		if (isDepthOffsetScaledWithEffect)
		{
			auto scale = (scaleValues.GetX() + scaleValues.GetY() + scaleValues.GetZ()) / 3.0f;
			offset *= scale;
		}

		if (isDepthOffsetScaledWithCamera)
		{
			auto t = mat.GetTranslation();
			auto c = t - cameraPos;
			auto cl = c.GetLength();

			if (cl != 0.0)
			{
				auto scale = (cl - offset) / cl;
				FastScale(mat, scale);
			}
		}

		auto objPos = mat.GetTranslation();
		auto dir = cameraPos - objPos;
		dir = dir.Normalize();

		if (isRightHand)
		{
			mat.SetTranslation(mat.GetTranslation() + dir * offset);
		}
		else
		{
			mat.SetTranslation(mat.GetTranslation() + dir * offset);
		}
	}

	if (depthParameter->SuppressionOfScalingByDepth < 1.0f)
	{
		auto t = mat.GetTranslation();
		auto c = t - cameraPos;
		auto cl = c.GetLength();

		if (cl != 0.0)
		{
			auto scale = cl / 32.0f * (1.0f - depthParameter->SuppressionOfScalingByDepth) + depthParameter->SuppressionOfScalingByDepth;
			FastScale(mat, scale);
		}
	}
}

void ApplyDepthParameters(::Effekseer::SIMD::Mat44f& mat,
						  const ::Effekseer::SIMD::Vec3f& cameraFront,
						  const ::Effekseer::SIMD::Vec3f& cameraPos,
						  ::Effekseer::NodeRendererDepthParameter* depthParameter,
						  bool isRightHand)
{
	auto depthOffset = depthParameter->DepthOffset;
	auto isDepthOffsetScaledWithCamera = depthParameter->IsDepthOffsetScaledWithCamera;
	auto isDepthOffsetScaledWithEffect = depthParameter->IsDepthOffsetScaledWithParticleScale;

	if (depthOffset != 0)
	{
		auto offset = depthOffset;

		if (isDepthOffsetScaledWithEffect)
		{
			auto scales = mat.GetScale();
			auto scale = (scales.GetX() + scales.GetY() + scales.GetZ()) / 3.0f;

			offset *= scale;
		}

		if (isDepthOffsetScaledWithCamera)
		{
			auto t = mat.GetTranslation();
			auto c = t - cameraPos;
			auto cl = c.GetLength();

			if (cl != 0.0)
			{
				auto scale = (cl - offset) / cl;
				FastScale(mat, scale);
			}
		}

		auto objPos = mat.GetTranslation();
		auto dir = cameraPos - objPos;
		dir = dir.Normalize();

		if (isRightHand)
		{
			mat.SetTranslation(mat.GetTranslation() + dir * offset);
		}
		else
		{
			mat.SetTranslation(mat.GetTranslation() + dir * offset);
		}
	}

	if (depthParameter->SuppressionOfScalingByDepth < 1.0f)
	{
		auto t = mat.GetTranslation();
		auto c = t - cameraPos;
		auto cl = c.GetLength();

		if (cl != 0.0)
		{
			auto scale = cl / 32.0f * (1.0f - depthParameter->SuppressionOfScalingByDepth) + depthParameter->SuppressionOfScalingByDepth;
			FastScale(mat, scale);
		}
	}
}

void ApplyViewOffset(::Effekseer::SIMD::Mat43f& mat,
					 const ::Effekseer::SIMD::Mat44f& camera,
					 float distance)
{
	::Effekseer::Matrix44 cameraMat;
	::Effekseer::Matrix44::Inverse(cameraMat, ToStruct(camera));

	::Effekseer::SIMD::Vec3f ViewOffset = ::Effekseer::SIMD::Vec3f::Load(cameraMat.Values[3]) + -::Effekseer::SIMD::Vec3f::Load(cameraMat.Values[2]) * distance;

	::Effekseer::SIMD::Vec3f localPos = mat.GetTranslation();
	ViewOffset += (::Effekseer::SIMD::Vec3f::Load(cameraMat.Values[0]) * localPos.GetX() +
				   ::Effekseer::SIMD::Vec3f::Load(cameraMat.Values[1]) * localPos.GetY() +
				   -::Effekseer::SIMD::Vec3f::Load(cameraMat.Values[2]) * localPos.GetZ());

	mat.SetTranslation(ViewOffset);
}

void ApplyViewOffset(::Effekseer::SIMD::Mat44f& mat,
					 const ::Effekseer::SIMD::Mat44f& camera,
					 float distance)
{
	::Effekseer::Matrix44 cameraMat;
	::Effekseer::Matrix44::Inverse(cameraMat, ToStruct(camera));

	::Effekseer::SIMD::Vec3f ViewOffset = ::Effekseer::SIMD::Vec3f::Load(cameraMat.Values[3]) + -::Effekseer::SIMD::Vec3f::Load(cameraMat.Values[2]) * distance;

	::Effekseer::SIMD::Vec3f localPos = mat.GetTranslation();
	ViewOffset += (::Effekseer::SIMD::Vec3f::Load(cameraMat.Values[0]) * localPos.GetX() +
				   ::Effekseer::SIMD::Vec3f::Load(cameraMat.Values[1]) * localPos.GetY() +
				   -::Effekseer::SIMD::Vec3f::Load(cameraMat.Values[2]) * localPos.GetZ());

	mat.SetTranslation(ViewOffset);
}

void CalculateAlignedTextureInformation(Effekseer::Backend::TextureFormatType format, const std::array<int, 2>& size, int32_t& sizePerWidth, int32_t& height)
{
	sizePerWidth = 0;
	height = 0;

	const int32_t blockSize = 4;
	auto aligned = [](int32_t size, int32_t alignement) -> int32_t {
		return ((size + alignement - 1) / alignement) * alignement;
	};

	if (format == Effekseer::Backend::TextureFormatType::R8G8B8A8_UNORM)
	{
		sizePerWidth = 4 * size[0];
		height = size[1];
	}
	else if (format == Effekseer::Backend::TextureFormatType::R8G8B8A8_UNORM_SRGB)
	{
		sizePerWidth = 4 * size[0];
		height = size[1];
	}
	else if (format == Effekseer::Backend::TextureFormatType::R8_UNORM)
	{
		sizePerWidth = 1 * size[0];
		height = size[1];
	}
	else if (format == Effekseer::Backend::TextureFormatType::R16G16_FLOAT)
	{
		sizePerWidth = sizeof(float) * 2 * size[0];
		height = size[1];
	}
	else if (format == Effekseer::Backend::TextureFormatType::R16G16B16A16_FLOAT)
	{
		sizePerWidth = sizeof(float) * 4 / 2 * size[0];
		height = size[1];
	}
	else if (format == Effekseer::Backend::TextureFormatType::R32G32B32A32_FLOAT)
	{
		sizePerWidth = sizeof(float) * 4 * size[0];
		height = size[1];
	}
	else if (format == Effekseer::Backend::TextureFormatType::BC1)
	{
		sizePerWidth = 8 * aligned(size[0], blockSize) / blockSize;
		height = aligned(size[1], blockSize) / blockSize;
	}
	else if (format == Effekseer::Backend::TextureFormatType::BC2)
	{
		sizePerWidth = 16 * aligned(size[0], blockSize) / blockSize;
		height = aligned(size[1], blockSize) / blockSize;
	}
	else if (format == Effekseer::Backend::TextureFormatType::BC3)
	{
		sizePerWidth = 16 * aligned(size[0], blockSize) / blockSize;
		height = aligned(size[1], blockSize) / blockSize;
	}
	else if (format == Effekseer::Backend::TextureFormatType::BC1_SRGB)
	{
		sizePerWidth = 8 * aligned(size[0], blockSize) / blockSize;
		height = aligned(size[1], blockSize) / blockSize;
	}
	else if (format == Effekseer::Backend::TextureFormatType::BC2_SRGB)
	{
		sizePerWidth = 16 * aligned(size[0], blockSize) / blockSize;
		height = aligned(size[1], blockSize) / blockSize;
	}
	else if (format == Effekseer::Backend::TextureFormatType::BC3_SRGB)
	{
		sizePerWidth = 16 * aligned(size[0], blockSize) / blockSize;
		height = aligned(size[1], blockSize) / blockSize;
	}
}

} // namespace EffekseerRenderer
