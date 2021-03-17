#include "ProcedualModelGenerator.h"
#include "../Effekseer.Random.h"
#include "../Model/Model.h"
#include "../Noise/CurlNoise.h"
#include "../Noise/PerlinNoise.h"
#include "../SIMD/Utils.h"
#include "ProcedualModelParameter.h"
#include "SplineGenerator.h"

#define _USE_MATH_DEFINES
#include <cmath>
#include <iterator>

namespace Effekseer
{

struct ProcedualMeshVertex
{
	SIMD::Vec3f Position;
	SIMD::Vec3f Normal;
	SIMD::Vec3f Tangent;
	SIMD::Vec2f UV;
	Color VColor;
};

struct ProcedualMeshFace
{
	std::array<int32_t, 3> Indexes;
};

struct ProcedualMesh
{
	CustomAlignedVector<ProcedualMeshVertex> Vertexes;
	CustomVector<ProcedualMeshFace> Faces;

	static ProcedualMesh Combine(ProcedualMesh mesh1, ProcedualMesh mesh2)
	{
		const auto vertexOffset = mesh1.Vertexes.size();
		const auto faceOffset = mesh1.Faces.size();

		std::copy(mesh2.Vertexes.begin(), mesh2.Vertexes.end(), std::back_inserter(mesh1.Vertexes));
		std::copy(mesh2.Faces.begin(), mesh2.Faces.end(), std::back_inserter(mesh1.Faces));

		for (size_t f = faceOffset; f < mesh1.Faces.size(); f++)
		{
			for (auto& ind : mesh1.Faces[f].Indexes)
			{
				ind += static_cast<int32_t>(vertexOffset);
			}
		}

		return std::move(mesh1);
	}
};

static float CalcSineWave(float x, float frequency, float offset, float power)
{
	return sinf(x * frequency + offset) * power;
}

static void CalcTangentSpace(const ProcedualMeshVertex& v1, const ProcedualMeshVertex& v2, const ProcedualMeshVertex& v3, SIMD::Vec3f& binormal, SIMD::Vec3f& tangent)
{
	binormal = SIMD::Vec3f();
	tangent = SIMD::Vec3f();

	SIMD::Vec3f cp0[3];
	cp0[0] = SIMD::Vec3f(v1.Position.GetX(), v1.UV.GetX(), v1.UV.GetY());
	cp0[1] = SIMD::Vec3f(v1.Position.GetY(), v1.UV.GetX(), v1.UV.GetY());
	cp0[2] = SIMD::Vec3f(v1.Position.GetZ(), v1.UV.GetX(), v1.UV.GetY());

	SIMD::Vec3f cp1[3];
	cp1[0] = SIMD::Vec3f(v2.Position.GetX(), v2.UV.GetX(), v2.UV.GetY());
	cp1[1] = SIMD::Vec3f(v2.Position.GetY(), v2.UV.GetX(), v2.UV.GetY());
	cp1[2] = SIMD::Vec3f(v2.Position.GetZ(), v2.UV.GetX(), v2.UV.GetY());

	SIMD::Vec3f cp2[3];
	cp2[0] = SIMD::Vec3f(v3.Position.GetX(), v3.UV.GetX(), v3.UV.GetY());
	cp2[1] = SIMD::Vec3f(v3.Position.GetY(), v3.UV.GetX(), v3.UV.GetY());
	cp2[2] = SIMD::Vec3f(v3.Position.GetZ(), v3.UV.GetX(), v3.UV.GetY());

	float u[3];
	float v[3];

	for (int32_t i = 0; i < 3; i++)
	{
		auto v1 = cp1[i] - cp0[i];
		auto v2 = cp2[i] - cp1[i];
		auto abc = SIMD::Vec3f::Cross(v1, v2);

		if (abc.GetX() == 0.0f)
		{
			return;
		}
		else
		{
			u[i] = -abc.GetY() / abc.GetX();
			v[i] = -abc.GetZ() / abc.GetX();
		}
	}

	tangent = SIMD::Vec3f(u[0], u[1], u[2]);
	tangent.Normalize();

	binormal = SIMD::Vec3f(v[0], v[1], v[2]);
	binormal.Normalize();
}

static void CalculateNormal(ProcedualMesh& mesh)
{
	CustomAlignedVector<SIMD::Vec3f> faceNormals;
	CustomAlignedVector<SIMD::Vec3f> faceTangents;

	faceNormals.resize(mesh.Faces.size());
	faceTangents.resize(mesh.Faces.size());

	for (size_t i = 0; i < faceNormals.size(); i++)
	{
		faceNormals[i] = SIMD::Vec3f(0.0f, 0.0f, 0.0f);
		faceTangents[i] = SIMD::Vec3f(0.0f, 0.0f, 0.0f);
	}

	for (size_t i = 0; i < mesh.Faces.size(); i++)
	{
		const auto& v1 = mesh.Vertexes[mesh.Faces[i].Indexes[0]];
		const auto& v2 = mesh.Vertexes[mesh.Faces[i].Indexes[1]];
		const auto& v3 = mesh.Vertexes[mesh.Faces[i].Indexes[2]];

		const auto eps = 0.0001f;
		if ((v1.Position - v2.Position).GetLength() < eps || (v2.Position - v3.Position).GetLength() < eps || (v1.Position - v3.Position).GetLength() < eps)
		{
			continue;
		}

		const auto normal = SIMD::Vec3f::Cross(v3.Position - v1.Position, v2.Position - v1.Position).Normalize();

		faceNormals[i] = normal;
		SIMD::Vec3f binotmal;
		SIMD::Vec3f tangent;

		CalcTangentSpace(v1, v2, v3, binotmal, tangent);

		faceTangents[i] = tangent;
	}

	CustomAlignedUnorderedMap<SIMD::Vec3f, SIMD::Vec3f> normals;
	CustomAlignedUnorderedMap<SIMD::Vec3f, SIMD::Vec3f> tangents;
	CustomAlignedUnorderedMap<SIMD::Vec3f, int32_t> vertexCounts;

	auto generateKey = [](SIMD::Vec3f s) -> SIMD::Vec3f {
		s.SetX(roundf(s.GetX() * 1024.0f));
		s.SetY(roundf(s.GetY() * 1024.0f));
		s.SetZ(roundf(s.GetZ() * 1024.0f));
		return s;
	};

	for (size_t i = 0; i < mesh.Faces.size(); i++)
	{
		for (size_t j = 0; j < 3; j++)
		{
			const auto& key = generateKey(mesh.Vertexes[mesh.Faces[i].Indexes[j]].Position);

			if (normals.count(key) == 0)
			{
				normals[key] = SIMD::Vec3f(0.0f, 0.0f, 0.0f);
				tangents[key] = SIMD::Vec3f(0.0f, 0.0f, 0.0f);
				vertexCounts[key] = 0;
			}

			if (faceNormals[i] == SIMD::Vec3f(0.0f, 0.0f, 0.0f))
			{
				continue;
			}

			normals[key] += faceNormals[i];
			tangents[key] += faceTangents[i];
			vertexCounts[key]++;
		}
	}

	for (size_t i = 0; i < mesh.Vertexes.size(); i++)
	{
		const auto& key = generateKey(mesh.Vertexes[i].Position);
		mesh.Vertexes[i].Normal = normals[key] / static_cast<float>(vertexCounts[key]);
		mesh.Vertexes[i].Tangent = tangents[key] / static_cast<float>(vertexCounts[key]);
	}
}

static void CalculateVertexColor(ProcedualMesh& mesh,
								 const Color& ColorLeft,
								 const Color& ColorCenter,
								 const Color& ColorRight,
								 const Color& ColorLeftMiddle,
								 const Color& ColorCenterMiddle,
								 const Color& ColorRightMiddle,
								 const std::array<float, 2>& colorCenterArea)
{
	auto calcColor = [&](float u, float v) -> Color {
		::Effekseer::Color leftColor;
		::Effekseer::Color centerColor;
		::Effekseer::Color rightColor;

		if (v < 0.5 - colorCenterArea[1] / 2.0f)
		{
			float l = v / (0.5f - (colorCenterArea[1] / 2.0f));

			leftColor.R = (uint8_t)Effekseer::Clamp(ColorLeft.R + (ColorLeftMiddle.R - ColorLeft.R) * l, 255, 0);
			leftColor.G = (uint8_t)Effekseer::Clamp(ColorLeft.G + (ColorLeftMiddle.G - ColorLeft.G) * l, 255, 0);
			leftColor.B = (uint8_t)Effekseer::Clamp(ColorLeft.B + (ColorLeftMiddle.B - ColorLeft.B) * l, 255, 0);
			leftColor.A = (uint8_t)Effekseer::Clamp(ColorLeft.A + (ColorLeftMiddle.A - ColorLeft.A) * l, 255, 0);

			centerColor.R =
				(uint8_t)Effekseer::Clamp(ColorCenter.R + (ColorCenterMiddle.R - ColorCenter.R) * l, 255, 0);
			centerColor.G =
				(uint8_t)Effekseer::Clamp(ColorCenter.G + (ColorCenterMiddle.G - ColorCenter.G) * l, 255, 0);
			centerColor.B =
				(uint8_t)Effekseer::Clamp(ColorCenter.B + (ColorCenterMiddle.B - ColorCenter.B) * l, 255, 0);
			centerColor.A =
				(uint8_t)Effekseer::Clamp(ColorCenter.A + (ColorCenterMiddle.A - ColorCenter.A) * l, 255, 0);

			rightColor.R =
				(uint8_t)Effekseer::Clamp(ColorRight.R + (ColorRightMiddle.R - ColorRight.R) * l, 255, 0);
			rightColor.G =
				(uint8_t)Effekseer::Clamp(ColorRight.G + (ColorRightMiddle.G - ColorRight.G) * l, 255, 0);
			rightColor.B =
				(uint8_t)Effekseer::Clamp(ColorRight.B + (ColorRightMiddle.B - ColorRight.B) * l, 255, 0);
			rightColor.A =
				(uint8_t)Effekseer::Clamp(ColorRight.A + (ColorRightMiddle.A - ColorRight.A) * l, 255, 0);
		}
		else if (v > 0.5f + colorCenterArea[1] / 2.0f)
		{
			float l = 1.0f - (v - 0.5f - colorCenterArea[1] / 2.0f) / (0.5f - colorCenterArea[1] / 2.0f);

			leftColor.R = (uint8_t)Effekseer::Clamp(ColorLeft.R + (ColorLeftMiddle.R - ColorLeft.R) * l, 255, 0);
			leftColor.G = (uint8_t)Effekseer::Clamp(ColorLeft.G + (ColorLeftMiddle.G - ColorLeft.G) * l, 255, 0);
			leftColor.B = (uint8_t)Effekseer::Clamp(ColorLeft.B + (ColorLeftMiddle.B - ColorLeft.B) * l, 255, 0);
			leftColor.A = (uint8_t)Effekseer::Clamp(ColorLeft.A + (ColorLeftMiddle.A - ColorLeft.A) * l, 255, 0);

			centerColor.R =
				(uint8_t)Effekseer::Clamp(ColorCenter.R + (ColorCenterMiddle.R - ColorCenter.R) * l, 255, 0);
			centerColor.G =
				(uint8_t)Effekseer::Clamp(ColorCenter.G + (ColorCenterMiddle.G - ColorCenter.G) * l, 255, 0);
			centerColor.B =
				(uint8_t)Effekseer::Clamp(ColorCenter.B + (ColorCenterMiddle.B - ColorCenter.B) * l, 255, 0);
			centerColor.A =
				(uint8_t)Effekseer::Clamp(ColorCenter.A + (ColorCenterMiddle.A - ColorCenter.A) * l, 255, 0);

			rightColor.R =
				(uint8_t)Effekseer::Clamp(ColorRight.R + (ColorRightMiddle.R - ColorRight.R) * l, 255, 0);
			rightColor.G =
				(uint8_t)Effekseer::Clamp(ColorRight.G + (ColorRightMiddle.G - ColorRight.G) * l, 255, 0);
			rightColor.B =
				(uint8_t)Effekseer::Clamp(ColorRight.B + (ColorRightMiddle.B - ColorRight.B) * l, 255, 0);
			rightColor.A =
				(uint8_t)Effekseer::Clamp(ColorRight.A + (ColorRightMiddle.A - ColorRight.A) * l, 255, 0);
		}
		else
		{
			leftColor = ColorLeftMiddle;
			centerColor = ColorCenterMiddle;
			rightColor = ColorRightMiddle;
		}

		if (u < 0.5f - colorCenterArea[0] / 2.0f)
		{
			float l = u / (0.5f - (colorCenterArea[0] / 2.0f));

			return Color::Lerp(leftColor, centerColor, l);
		}
		else if (u > 0.5f + colorCenterArea[0] / 2.0f)
		{
			float l = (u - 0.5f - colorCenterArea[0] / 2.0f) / (0.5f - colorCenterArea[0] / 2.0f);

			return Color::Lerp(centerColor, rightColor, l);
		}
		else
		{
			return centerColor;
		}
	};

	for (auto& v : mesh.Vertexes)
	{
		v.VColor = calcColor(v.UV.GetX(), v.UV.GetY());
	}
}

static void ChangeAxis(ProcedualMesh& mesh, ProcedualModelAxisType axisType)
{
	if (axisType == ProcedualModelAxisType::Y)
		return;

	if (axisType == ProcedualModelAxisType::X)
	{
		const auto swapAxis = [](SIMD::Vec3f& v) -> void {
			auto x = v.GetX();
			auto y = v.GetY();
			v.SetY(x);
			v.SetX(y);
		};

		for (auto& v : mesh.Vertexes)
		{
			swapAxis(v.Position);
			swapAxis(v.Normal);
			swapAxis(v.Tangent);
		}
	}
	else if (axisType == ProcedualModelAxisType::Z)
	{
		const auto swapAxis = [](SIMD::Vec3f& v) -> void {
			auto z = v.GetZ();
			auto y = v.GetY();
			v.SetY(z);
			v.SetZ(y);
		};

		for (auto& v : mesh.Vertexes)
		{
			swapAxis(v.Position);
			swapAxis(v.Normal);
			swapAxis(v.Tangent);
		}
	}
}

static ModelRef ConvertMeshToModel(const ProcedualMesh& mesh)
{
	CustomVector<Model::Vertex> vs;
	CustomVector<Model::Face> faces;

	vs.resize(mesh.Vertexes.size());
	faces.resize(mesh.Faces.size());

	for (size_t i = 0; i < vs.size(); i++)
	{
		vs[i].Position = ToStruct(mesh.Vertexes[i].Position);
		vs[i].Normal = ToStruct(mesh.Vertexes[i].Normal);
		vs[i].Tangent = ToStruct(mesh.Vertexes[i].Tangent);
		vs[i].UV = ToStruct(mesh.Vertexes[i].UV);
		Vector3D::Cross(vs[i].Binormal, vs[i].Normal, vs[i].Tangent);
		Vector3D::Normal(vs[i].Binormal, vs[i].Binormal);
		vs[i].VColor = mesh.Vertexes[i].VColor;
	}

	for (size_t i = 0; i < faces.size(); i++)
	{
		faces[i].Indexes[0] = mesh.Faces[i].Indexes[0];
		faces[i].Indexes[1] = mesh.Faces[i].Indexes[1];
		faces[i].Indexes[2] = mesh.Faces[i].Indexes[2];
	}

	return ::Effekseer::MakeRefPtr<Model>(vs, faces);
}

struct RotatorSphere
{
	float Radius;
	float DepthMin;
	float DepthMax;

	SIMD::Vec2f GetPosition(float value) const
	{
		const auto depthMax = Clamp(DepthMax, Radius, -Radius);
		const auto depthMin = Clamp(DepthMin, Radius, -Radius);

		float angleMax = atan2f(depthMax, sqrtf(Radius * Radius - depthMax * depthMax));
		float angleMin = atan2f(depthMin, sqrtf(Radius * Radius - depthMin * depthMin));

		float angle = (angleMax - angleMin) * value + angleMin;

		if (value == 1.0f)
		{
			angle = angleMax;
		}
		else if (value == 0.0f)
		{
			angle = angleMin;
		}

		float valueMin = depthMin * Radius;
		float valueMax = depthMax * Radius;

		value = Clamp(value, 1.0f, 0.0f);

		return SIMD::Vec2f(cosf(angle) * Radius, sinf(angle) * Radius);
	}
};

struct RotatorCone
{
	float Radius;
	float Depth;

	SIMD::Vec2f GetPosition(float value) const
	{
		value = Clamp(value, 1.0f, 0.0f);
		float axisPos = Depth * value;
		return SIMD::Vec2f(Radius / Depth * axisPos, axisPos);
	}
};

struct RotatorCylinder
{
	float Radius1;
	float Radius2;
	float Depth;

	SIMD::Vec2f GetPosition(float value) const
	{
		value = Clamp(value, 1.0f, 0.0f);

		float axisPos = Depth * value;
		return SIMD::Vec2f((Radius2 - Radius1) * value + Radius1, axisPos);
	}
};

struct RotatorSpline3
{
	std::array<float, 2> Point1;
	std::array<float, 2> Point2;
	std::array<float, 2> Point3;
	std::array<float, 2> Point4;

	SplineGenerator generator;
	std::vector<float> distances_;
	float sumDistance_ = 0.0f;

	void Calculate()
	{
		generator.AddVertex({Point1[0], Point1[1], 0.0f});
		generator.AddVertex({Point2[0], Point2[1], 0.0f});
		generator.AddVertex({Point3[0], Point3[1], 0.0f});
		generator.AddVertex({Point4[0], Point4[1], 0.0f});
		generator.Calculate();

		distances_.emplace_back((SIMD::Vec2f(Point2) - SIMD::Vec2f(Point1)).Length());
		distances_.emplace_back((SIMD::Vec2f(Point3) - SIMD::Vec2f(Point2)).Length());
		distances_.emplace_back((SIMD::Vec2f(Point4) - SIMD::Vec2f(Point3)).Length());

		sumDistance_ = 0.0f;
		for (auto d : distances_)
		{
			sumDistance_ += d;
		}
	}

	SIMD::Vec2f GetPosition(float value) const
	{
		value = Clamp(value, 1.0f, 0.0f);

		auto distance = sumDistance_ * value;

		for (size_t i = 0; i < distances_.size(); i++)
		{
			if (distance <= distances_[i])
			{
				value = i + distance / distances_[i];
				return SIMD::Vec2f(generator.GetValue(value).GetX(), generator.GetValue(value).GetY());
			}

			distance -= distances_[i];
		}

		value = static_cast<float>(distances_.size());

		return SIMD::Vec2f(generator.GetValue(value).GetX(), generator.GetValue(value).GetY());
	}
};

static SIMD::Vec3f WaveNoise(SIMD::Vec3f v, std::array<float, 3> waveOffsets, std::array<float, 3> waveFrequency, std::array<float, 3> noiseScales)
{

	return v + SIMD::Vec3f(
				   CalcSineWave(v.GetY(), waveFrequency[0], waveOffsets[0], noiseScales[0]),
				   CalcSineWave(v.GetY(), waveFrequency[1], waveOffsets[1], noiseScales[1]),
				   CalcSineWave(v.GetY(), waveFrequency[2], waveOffsets[2], noiseScales[2]));
}

struct RotatorMeshGenerator
{
	float AngleMin;
	float AngleMax;
	bool IsConnected = false;

	std::function<SIMD::Vec2f(float)> Rotator;
	std::function<SIMD::Vec3f(SIMD::Vec3f)> Noise;

	SIMD::Vec3f GetPosition(float angleValue, float depthValue) const
	{
		depthValue = Clamp(depthValue, 1.0f, 0.0f);
		auto angle = (AngleMax - AngleMin) * angleValue + AngleMin;

		SIMD::Vec2f pos2d = Rotator(depthValue);

		float s;
		float c;
		SinCos(angle, s, c);
		auto x = pos2d.GetX();
		//x += sin(depthValue) * 0.4f;
		auto rx = x * s;
		auto rz = x * c;
		auto y = pos2d.GetY();

		return SIMD::Vec3f(rx, y, rz);
	}

	ProcedualMesh Generate(int32_t angleDivision, int32_t depthDivision) const
	{
		assert(depthDivision > 1);
		assert(angleDivision > 1);

		ProcedualMesh ret;

		ret.Vertexes.resize(depthDivision * angleDivision);
		ret.Faces.resize((depthDivision - 1) * (angleDivision - 1) * 2);

		for (int32_t v = 0; v < depthDivision; v++)
		{
			for (int32_t u = 0; u < angleDivision; u++)
			{
				ret.Vertexes[u + v * angleDivision].Position = GetPosition(u / float(angleDivision - 1), v / float(depthDivision - 1));
				ret.Vertexes[u + v * angleDivision].UV = SIMD::Vec2f(u / float(angleDivision - 1), 1.0f - v / float(depthDivision - 1));
			}
		}

		if (IsConnected)
		{
			for (int32_t v = 0; v < depthDivision; v++)
			{
				ret.Vertexes[(angleDivision - 1) + v * angleDivision].Position = ret.Vertexes[0 + v * angleDivision].Position;
			}
		}

		for (int32_t v = 0; v < depthDivision - 1; v++)
		{
			for (int32_t u = 0; u < angleDivision - 1; u++)
			{
				ProcedualMeshFace face0;
				ProcedualMeshFace face1;

				int32_t v00 = (u + 0) + (v + 0) * (angleDivision);
				int32_t v10 = (u + 1) + (v + 0) * (angleDivision);
				int32_t v01 = (u + 0) + (v + 1) * (angleDivision);
				int32_t v11 = (u + 1) + (v + 1) * (angleDivision);

				face0.Indexes[0] = v00;
				face0.Indexes[1] = v11;
				face0.Indexes[2] = v10;

				face1.Indexes[0] = v00;
				face1.Indexes[1] = v01;
				face1.Indexes[2] = v11;

				ret.Faces[(u + v * (angleDivision - 1)) * 2 + 0] = face0;
				ret.Faces[(u + v * (angleDivision - 1)) * 2 + 1] = face1;
			}
		}

		for (size_t i = 0; i < ret.Vertexes.size(); i++)
		{
			ret.Vertexes[i].Position = Noise(ret.Vertexes[i].Position);
		}

		return ret;
	}
};

struct RotatedWireMeshGenerator
{
	float Rotate;
	int Vertices;
	int Count;

	std::array<float, 2> RibbonNoises;
	std::array<float, 2> RibbonAngles;
	std::array<float, 2> RibbonSizes;

	std::function<SIMD::Vec2f(float)> Rotator;
	std::function<SIMD::Vec3f(SIMD::Vec3f)> Noise;

	ProcedualModelCrossSectionType CrossSectionType;

	SIMD::Vec3f GetPosition(float angleValue, float depthValue) const
	{
		auto value = depthValue;
		auto angle = angleValue;

		SIMD::Vec2f pos2d = Rotator(value);

		float s;
		float c;
		SinCos(angle, s, c);

		auto x = pos2d.GetX();
		auto rx = x * s;
		auto rz = x * c;
		auto y = pos2d.GetY();

		return SIMD::Vec3f(rx, y, rz);
	}

	ProcedualMesh Generate(RandObject& randObj) const
	{
		std::vector<SIMD::Vec3f> vertexPoses;
		std::vector<int32_t> edgeIDs;
		std::vector<float> edgeUVs;

		if (CrossSectionType == ProcedualModelCrossSectionType::Cross)
		{
			vertexPoses = {
				SIMD::Vec3f(+0.5f, 0.0f, 0.0f),
				SIMD::Vec3f(+0.0f, 0.0f, 0.0f),
				SIMD::Vec3f(-0.5f, 0.0f, 0.0f),
				SIMD::Vec3f(0.0f, 0.0f, -0.5f),
				SIMD::Vec3f(0.0f, 0.0f, +0.0f),
				SIMD::Vec3f(0.0f, 0.0f, +0.5f),
			};

			edgeIDs = {
				0,
				1,
				1,
				2,
				3,
				4,
				4,
				5,
			};

			edgeUVs = {
				0.0f,
				0.5f,
				1.0f,
				0.0f,
				0.5f,
				1.0f,
			};
		}
		else if (CrossSectionType == ProcedualModelCrossSectionType::Plane)
		{
			vertexPoses = {
				SIMD::Vec3f(+0.5f, 0.0f, 0.0f),
				SIMD::Vec3f(+0.0f, 0.0f, 0.0f),
				SIMD::Vec3f(-0.5f, 0.0f, 0.0f),
			};

			edgeIDs = {
				0,
				1,
				1,
				2,
			};

			edgeUVs = {
				0.0f,
				0.5f,
				1.0f,
			};
		}
		else if (CrossSectionType == ProcedualModelCrossSectionType::Point)
		{
			vertexPoses = {
				SIMD::Vec3f(0.0f, 0.0f, 0.0f),
			};

			edgeIDs = {
				0,
			};

			edgeUVs = {
				0.0f,
			};
		}
		
		ProcedualMesh ret;

		for (int32_t l = 0; l < Count; l++)
		{
			float currentDepth = RibbonNoises[1] / 2.0f * randObj.GetRand();
			float endDepth = 1.0f - RibbonNoises[1] / 2.0f * randObj.GetRand();
			float currentAngle = (static_cast<float>(l) / static_cast<float>(Count) + RibbonNoises[0] * (randObj.GetRand() - 0.5f)) * EFK_PI * 2.0f;

			CustomAlignedVector<SIMD::Vec3f> vs;
			CustomAlignedVector<SIMD::Vec3f> binormals;
			CustomAlignedVector<SIMD::Vec3f> normals;

			float depthSpeed = (endDepth - currentDepth) / static_cast<float>(Vertices);
			float rotateSpeed = Rotate * (endDepth - currentDepth) * EFK_PI * 2.0f / static_cast<float>(Vertices);

			while (currentDepth < endDepth)
			{
				auto pos = GetPosition(currentAngle, currentDepth);

				const auto eps = 0.0001f;
				auto pos_diff = GetPosition(currentAngle + eps * rotateSpeed, currentDepth + eps * depthSpeed);
				auto pos_diff_angle = GetPosition(currentAngle + eps, currentDepth);
				auto pos_diff_axis = GetPosition(currentAngle, currentDepth + eps);
				auto normal = SIMD::Vec3f::Cross(pos_diff_angle - pos, pos_diff_axis - pos);

				vs.emplace_back(pos);
				normals.emplace_back(normal.Normalize());
				binormals.emplace_back((pos_diff - pos).Normalize());
				currentDepth += depthSpeed;
				currentAngle += rotateSpeed;
			}

			if (vs.size() < 2)
			{
				return {};
			}

			ProcedualMesh ribbon;

			ribbon.Vertexes.resize(vs.size() * vertexPoses.size());

			for (int32_t v = 0; v < vs.size(); v++)
			{
				const auto tangent = SIMD::Vec3f::Cross(normals[v], binormals[v]).Normalize();
				const auto normal = normals[v];

				const auto percent = v / static_cast<float>(vs.size() - 1);

				const auto scale = (RibbonSizes[1] - RibbonSizes[0]) * percent + RibbonSizes[0];
				const auto angle = ((RibbonAngles[1] - RibbonAngles[0]) * percent + RibbonAngles[0]) / 180.0f * EFK_PI;

				const auto c = cosf(angle);
				const auto s = sinf(angle);

				const auto rtangent = tangent * c + normal * s;
				const auto rnormal = -tangent * s + normal * c;

				for (size_t i = 0; i < vertexPoses.size(); i++)
				{
					ribbon.Vertexes[v * vertexPoses.size() + i].Position = vs[v] + (rtangent * vertexPoses[i].GetX() + binormals[v] * vertexPoses[i].GetY() + rnormal * vertexPoses[i].GetZ()) * scale;
					ribbon.Vertexes[v * vertexPoses.size() + i].UV = SIMD::Vec2f(edgeUVs[i], 1.0f - v / static_cast<float>(vs.size() - 1));
				}
			}

			ribbon.Faces.resize((vs.size() - 1) * edgeIDs.size());

			for (int32_t v = 0; v < vs.size() - 1; v++)
			{
				for (size_t i = 0; i < edgeIDs.size() / 2; i++)
				{
					ProcedualMeshFace face0{};
					ProcedualMeshFace face1{};

					int32_t v00 = (edgeIDs[i * 2 + 0]) + (v + 0) * static_cast<int32_t>(vertexPoses.size());
					int32_t v10 = (edgeIDs[i * 2 + 1]) + (v + 0) * static_cast<int32_t>(vertexPoses.size());
					int32_t v01 = (edgeIDs[i * 2 + 0]) + (v + 1) * static_cast<int32_t>(vertexPoses.size());
					int32_t v11 = (edgeIDs[i * 2 + 1]) + (v + 1) * static_cast<int32_t>(vertexPoses.size());

					face0.Indexes[0] = v00;
					face0.Indexes[1] = v11;
					face0.Indexes[2] = v10;

					face1.Indexes[0] = v00;
					face1.Indexes[1] = v01;
					face1.Indexes[2] = v11;

					ribbon.Faces[v * edgeIDs.size() + i * 2 + 0] = face0;
					ribbon.Faces[v * edgeIDs.size() + i * 2 + 1] = face1;
				}
			}

			for (size_t i = 0; i < ribbon.Vertexes.size(); i++)
			{
				ribbon.Vertexes[i].Position = Noise(ribbon.Vertexes[i].Position);
			}

			CalculateNormal(ribbon);

			ret = ProcedualMesh::Combine(std::move(ret), std::move(ribbon));
		}

		return std::move(ret);
	}
};

ModelRef ProcedualModelGenerator::Generate(const ProcedualModelParameter* parameter)
{
	if (parameter == nullptr)
	{
		return nullptr;
	}

	RandObject randObj;
	CurlNoise curlNoise(0, 1.0f, 2);

	std::function<SIMD::Vec2f(float)> primitiveGenerator;

	if (parameter->PrimitiveType == ProcedualModelPrimitiveType::Sphere)
	{
		RotatorSphere rotator;
		rotator.DepthMin = parameter->Sphere.DepthMin;
		rotator.DepthMax = parameter->Sphere.DepthMax;
		rotator.Radius = parameter->Sphere.Radius;

		primitiveGenerator = [rotator](float value) -> SIMD::Vec2f {
			return rotator.GetPosition(value);
		};
	}
	else if (parameter->PrimitiveType == ProcedualModelPrimitiveType::Cone)
	{
		RotatorCone rotator;
		rotator.Radius = parameter->Cone.Radius;
		rotator.Depth = parameter->Cone.Depth;

		primitiveGenerator = [rotator](float value) -> SIMD::Vec2f {
			return rotator.GetPosition(value);
		};
	}
	else if (parameter->PrimitiveType == ProcedualModelPrimitiveType::Cylinder)
	{
		RotatorCylinder rotator;
		rotator.Radius1 = parameter->Cylinder.Radius1;
		rotator.Radius2 = parameter->Cylinder.Radius2;
		rotator.Depth = parameter->Cylinder.Depth;

		primitiveGenerator = [rotator](float value) -> SIMD::Vec2f {
			return rotator.GetPosition(value);
		};
	}
	else if (parameter->PrimitiveType == ProcedualModelPrimitiveType::Spline4)
	{
		RotatorSpline3 rotator;
		rotator.Point1 = parameter->Spline4.Point1;
		rotator.Point2 = parameter->Spline4.Point2;
		rotator.Point3 = parameter->Spline4.Point3;
		rotator.Point4 = parameter->Spline4.Point4;
		rotator.Calculate();

		primitiveGenerator = [rotator](float value) -> SIMD::Vec2f {
			return rotator.GetPosition(value);
		};
	}
	else
	{
		assert(0);
	}

	std::function<SIMD::Vec3f(SIMD::Vec3f)> noiseFunc = [parameter, &curlNoise](SIMD::Vec3f v) -> SIMD::Vec3f {
		// tilt noise
		{
			float angleX = CalcSineWave(v.GetY(), parameter->TiltNoiseFrequency[0], parameter->TiltNoiseOffset[0], parameter->TiltNoisePower[0]);
			float angleY = CalcSineWave(v.GetY(), parameter->TiltNoiseFrequency[1], parameter->TiltNoiseOffset[1], parameter->TiltNoisePower[1]);

			SIMD::Vec3f dirX(cos(angleX), sin(angleX), 0.0f);
			SIMD::Vec3f dirZ(0.0f, sin(angleY), cos(angleY));
			SIMD::Vec3f dirY = SIMD::Vec3f::Cross(dirZ, dirX).Normalize();
			dirZ = SIMD::Vec3f::Cross(dirX, dirY).Normalize();

			v = SIMD::Vec3f(0.0f, v.GetY(), 0.0f) + dirX * v.GetX() + dirZ * v.GetZ();
		}

		v = WaveNoise(v,
					  parameter->WaveNoiseOffset,
					  parameter->WaveNoiseFrequency,
					  parameter->WaveNoisePower);

		return v + curlNoise.Get(v * parameter->CurlNoiseFrequency + parameter->CurlNoiseOffset) * parameter->CurlNoisePower;
	};

	if (parameter->Type == ProcedualModelType::Mesh)
	{
		const auto AngleBegin = parameter->Mesh.AngleBegin / 180.0f * EFK_PI;
		const auto AngleEnd = parameter->Mesh.AngleEnd / 180.0f * EFK_PI;
		const auto eps = 0.000001f;
		const auto isConnected = std::fmod(std::abs(parameter->Mesh.AngleBegin - parameter->Mesh.AngleEnd), 360.0f) < eps;

		auto generator = RotatorMeshGenerator();
		generator.Rotator = primitiveGenerator;
		generator.Noise = noiseFunc;
		generator.AngleMin = AngleBegin;
		generator.AngleMax = AngleEnd;
		generator.IsConnected = isConnected;
		auto generated = generator.Generate(parameter->Mesh.Divisions[0], parameter->Mesh.Divisions[1]);
		CalculateNormal(generated);
		CalculateVertexColor(generated, parameter->ColorLeft, parameter->ColorCenter, parameter->ColorRight, parameter->ColorLeftMiddle, parameter->ColorCenterMiddle, parameter->ColorRightMiddle, parameter->ColorCenterArea);
		ChangeAxis(generated, parameter->AxisType);

		return ConvertMeshToModel(generated);
	}
	else if (parameter->Type == ProcedualModelType::Ribbon)
	{
		auto generator = RotatedWireMeshGenerator();
		generator.Rotator = primitiveGenerator;
		generator.Noise = noiseFunc;
		generator.CrossSectionType = parameter->Ribbon.CrossSection;
		generator.Vertices = parameter->Ribbon.Vertices;
		generator.Rotate = parameter->Ribbon.Rotate;
		generator.Count = parameter->Ribbon.Count;
		generator.RibbonSizes = parameter->Ribbon.RibbonSizes;
		generator.RibbonAngles = parameter->Ribbon.RibbonAngles;
		generator.RibbonNoises = parameter->Ribbon.RibbonNoises;

		auto generated = generator.Generate(randObj);

		CalculateNormal(generated);
		CalculateVertexColor(generated, parameter->ColorLeft, parameter->ColorCenter, parameter->ColorRight, parameter->ColorLeftMiddle, parameter->ColorCenterMiddle, parameter->ColorRightMiddle, parameter->ColorCenterArea);
		ChangeAxis(generated, parameter->AxisType);

		return ConvertMeshToModel(generated);
	}

	return nullptr;
}

void ProcedualModelGenerator::Ungenerate(ModelRef model)
{
}

} // namespace Effekseer