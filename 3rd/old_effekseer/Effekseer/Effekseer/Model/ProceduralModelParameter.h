#ifndef __EFFEKSEER_PROCEDUAL_MODEL_PARAMETER_H__
#define __EFFEKSEER_PROCEDUAL_MODEL_PARAMETER_H__

#include "../Effekseer.Color.h"
#include "../Utils/BinaryVersion.h"
#include "../Utils/Effekseer.BinaryReader.h"
#include <stdint.h>
#include <stdio.h>

namespace Effekseer
{

/*
inline bool operator<(const std::array<float, 2>& lhs, const std::array<float, 2>& rhs)
{
	for (size_t i = 0; i < lhs.size(); i++)
	{
		if (lhs[i] != rhs[i])
		{
			return lhs[i] < rhs[i];
		}
	}

	return false;
}

inline bool operator<(const std::array<float, 3>& lhs, const std::array<float, 3>& rhs)
{
	for (size_t i = 0; i < lhs.size(); i++)
	{
		if (lhs[i] != rhs[i])
		{
			return lhs[i] < rhs[i];
		}
	}

	return false;
}
*/

enum class ProceduralModelType : int32_t
{
	Mesh,
	Ribbon,
};

enum class ProceduralModelPrimitiveType : int32_t
{
	Sphere,
	Cone,
	Cylinder,
	Spline4,
};

enum class ProceduralModelCrossSectionType : int32_t
{
	Plane,
	Cross,
	Point,
};

enum class ProceduralModelAxisType : int32_t
{
	X,
	Y,
	Z,
};

struct ProceduralModelParameter
{
	ProceduralModelType Type = ProceduralModelType::Mesh;
	ProceduralModelPrimitiveType PrimitiveType = ProceduralModelPrimitiveType::Sphere;
	ProceduralModelAxisType AxisType = ProceduralModelAxisType::Y;

	union
	{
		struct
		{
			float AngleBegin;
			float AngleEnd;
			std::array<int, 2> Divisions;
			float Rotate;
		} Mesh;

		struct
		{
			ProceduralModelCrossSectionType CrossSection;
			float Rotate;
			int Vertices;
			std::array<float, 2> RibbonSizes;
			std::array<float, 2> RibbonAngles;
			std::array<float, 2> RibbonNoises;
			int Count;
		} Ribbon;
	};

	union
	{
		struct
		{
			float Radius;
			float DepthMin;
			float DepthMax;
		} Sphere;

		struct
		{
			float Radius;
			float Depth;
		} Cone;

		struct
		{
			float Radius1;
			float Radius2;
			float Depth;
		} Cylinder;

		struct
		{
			std::array<float, 2> Point1;
			std::array<float, 2> Point2;
			std::array<float, 2> Point3;
			std::array<float, 2> Point4;
		} Spline4;
	};

	std::array<float, 2> TiltNoiseFrequency = {};
	std::array<float, 2> TiltNoiseOffset = {};
	std::array<float, 2> TiltNoisePower = {};

	std::array<float, 3> WaveNoiseFrequency = {};
	std::array<float, 3> WaveNoiseOffset = {};
	std::array<float, 3> WaveNoisePower = {};

	std::array<float, 3> CurlNoiseFrequency = {};
	std::array<float, 3> CurlNoiseOffset = {};
	std::array<float, 3> CurlNoisePower = {};

	std::array<float, 2> ColorCenterPosition = {0.5f, 0.5f};
	std::array<float, 2> ColorCenterArea = {0.0f, 0.0f};

	Color ColorUpperLeft;
	Color ColorUpperCenter;
	Color ColorUpperRight;
	Color ColorMiddleLeft;
	Color ColorMiddleCenter;
	Color ColorMiddleRight;
	Color ColorLowerLeft;
	Color ColorLowerCenter;
	Color ColorLowerRight;

	std::array<float, 3> VertexColorNoiseFrequency = {};
	std::array<float, 3> VertexColorNoiseOffset = {};
	std::array<float, 3> VertexColorNoisePower = {};

	std::array<float, 2> UVPosition = {0.0f, 0.5f};
	std::array<float, 2> UVSize = {1.0f, 1.0f};

	bool operator<(const ProceduralModelParameter& rhs) const
	{
		if (Type != rhs.Type)
		{
			return static_cast<int32_t>(Type) < static_cast<int32_t>(rhs.Type);
		}

		if (Type == ProceduralModelType::Mesh)
		{
			if (Mesh.AngleBegin != rhs.Mesh.AngleBegin)
				return Mesh.AngleBegin < rhs.Mesh.AngleBegin;

			if (Mesh.AngleEnd != rhs.Mesh.AngleEnd)
				return Mesh.AngleEnd < rhs.Mesh.AngleEnd;

			if (Mesh.Divisions[0] != rhs.Mesh.Divisions[0])
				return Mesh.Divisions[0] < rhs.Mesh.Divisions[0];

			if (Mesh.Divisions[1] != rhs.Mesh.Divisions[1])
				return Mesh.Divisions[1] < rhs.Mesh.Divisions[1];

			if (Mesh.Rotate != rhs.Mesh.Rotate)
				return Mesh.Rotate < rhs.Mesh.Rotate;
		}
		else if (Type == ProceduralModelType::Ribbon)
		{
			if (Ribbon.CrossSection != rhs.Ribbon.CrossSection)
				return Ribbon.CrossSection < rhs.Ribbon.CrossSection;

			if (Ribbon.Rotate != rhs.Ribbon.Rotate)
				return Ribbon.Rotate < rhs.Ribbon.Rotate;

			if (Ribbon.Vertices != rhs.Ribbon.Vertices)
				return Ribbon.Vertices < rhs.Ribbon.Vertices;

			if (Ribbon.RibbonSizes != rhs.Ribbon.RibbonSizes)
				return Ribbon.RibbonSizes < rhs.Ribbon.RibbonSizes;
			if (Ribbon.RibbonAngles != rhs.Ribbon.RibbonAngles)
				return Ribbon.RibbonAngles < rhs.Ribbon.RibbonAngles;
			if (Ribbon.RibbonNoises[0] != rhs.Ribbon.RibbonNoises[0])
				return Ribbon.RibbonNoises[0] < rhs.Ribbon.RibbonNoises[0];

			if (Ribbon.RibbonNoises[1] != rhs.Ribbon.RibbonNoises[1])
				return Ribbon.RibbonNoises[1] < rhs.Ribbon.RibbonNoises[1];

			if (Ribbon.Count != rhs.Ribbon.Count)
				return Ribbon.Count < rhs.Ribbon.Count;
		}
		else
		{
			assert(0);
		}

		if (PrimitiveType != rhs.PrimitiveType)
		{
			return static_cast<int32_t>(PrimitiveType) < static_cast<int32_t>(rhs.PrimitiveType);
		}

		if (PrimitiveType == ProceduralModelPrimitiveType::Sphere)
		{
			if (Sphere.Radius != rhs.Sphere.Radius)
				return Sphere.Radius < rhs.Sphere.Radius;

			if (Sphere.DepthMin != rhs.Sphere.DepthMin)
				return Sphere.DepthMin < rhs.Sphere.DepthMin;

			if (Sphere.DepthMax != rhs.Sphere.DepthMax)
				return Sphere.DepthMax < rhs.Sphere.DepthMax;
		}
		else if (PrimitiveType == ProceduralModelPrimitiveType::Cone)
		{
			if (Cone.Radius != rhs.Cone.Radius)
				return Cone.Radius < rhs.Cone.Radius;

			if (Cone.Depth != rhs.Cone.Depth)
				return Cone.Depth < rhs.Cone.Depth;
		}
		else if (PrimitiveType == ProceduralModelPrimitiveType::Cylinder)
		{
			if (Cylinder.Radius1 != rhs.Cylinder.Radius1)
				return Cylinder.Radius1 < rhs.Cylinder.Radius1;

			if (Cylinder.Radius2 != rhs.Cylinder.Radius2)
				return Cylinder.Radius2 < rhs.Cylinder.Radius2;

			if (Cylinder.Depth != rhs.Cylinder.Depth)
				return Cylinder.Depth < rhs.Cylinder.Depth;
		}
		else if (PrimitiveType == ProceduralModelPrimitiveType::Spline4)
		{
			if (Spline4.Point1 != rhs.Spline4.Point1)
				return Spline4.Point1 < rhs.Spline4.Point1;

			if (Spline4.Point2 != rhs.Spline4.Point2)
				return Spline4.Point2 < rhs.Spline4.Point2;

			if (Spline4.Point3 != rhs.Spline4.Point3)
				return Spline4.Point3 < rhs.Spline4.Point3;

			if (Spline4.Point4 != rhs.Spline4.Point4)
				return Spline4.Point4 < rhs.Spline4.Point4;
		}
		else
		{
			assert(0);
		}

		if (AxisType != rhs.AxisType)
		{
			return static_cast<int32_t>(AxisType) < static_cast<int32_t>(rhs.AxisType);
		}

		if (TiltNoiseFrequency != rhs.TiltNoiseFrequency)
			return TiltNoiseFrequency < rhs.TiltNoiseFrequency;

		if (TiltNoiseOffset != rhs.TiltNoiseOffset)
			return TiltNoiseOffset < rhs.TiltNoiseOffset;

		if (TiltNoisePower != rhs.TiltNoisePower)
			return TiltNoisePower < rhs.TiltNoisePower;

		if (WaveNoiseFrequency != rhs.WaveNoiseFrequency)
			return WaveNoiseFrequency < rhs.WaveNoiseFrequency;

		if (WaveNoiseOffset != rhs.WaveNoiseOffset)
			return WaveNoiseOffset < rhs.WaveNoiseOffset;

		if (WaveNoisePower != rhs.WaveNoisePower)
			return WaveNoisePower < rhs.WaveNoisePower;

		if (CurlNoiseFrequency != rhs.CurlNoiseFrequency)
			return CurlNoiseFrequency < rhs.CurlNoiseFrequency;

		if (CurlNoiseOffset != rhs.CurlNoiseOffset)
			return CurlNoiseOffset < rhs.CurlNoiseOffset;

		if (CurlNoisePower != rhs.CurlNoisePower)
			return CurlNoisePower < rhs.CurlNoisePower;

		if (ColorUpperLeft != rhs.ColorUpperLeft)
			return ColorUpperLeft < rhs.ColorUpperLeft;

		if (ColorUpperCenter != rhs.ColorUpperCenter)
			return ColorUpperCenter < rhs.ColorUpperCenter;

		if (ColorUpperRight != rhs.ColorUpperRight)
			return ColorUpperRight < rhs.ColorUpperRight;

		if (ColorMiddleLeft != rhs.ColorMiddleLeft)
			return ColorMiddleLeft < rhs.ColorMiddleLeft;

		if (ColorMiddleCenter != rhs.ColorMiddleCenter)
			return ColorMiddleCenter < rhs.ColorMiddleCenter;

		if (ColorMiddleRight != rhs.ColorMiddleRight)
			return ColorMiddleRight < rhs.ColorMiddleRight;

		if (ColorLowerLeft != rhs.ColorLowerLeft)
			return ColorLowerLeft < rhs.ColorLowerLeft;

		if (ColorLowerCenter != rhs.ColorLowerCenter)
			return ColorLowerCenter < rhs.ColorLowerCenter;

		if (ColorLowerRight != rhs.ColorLowerRight)
			return ColorLowerRight < rhs.ColorLowerRight;

		if (ColorCenterPosition != rhs.ColorCenterPosition)
			return ColorCenterPosition < rhs.ColorCenterPosition;

		if (ColorCenterArea != rhs.ColorCenterArea)
			return ColorCenterArea < rhs.ColorCenterArea;

		if (VertexColorNoiseFrequency != rhs.VertexColorNoiseFrequency)
			return VertexColorNoiseFrequency < rhs.VertexColorNoiseFrequency;

		if (VertexColorNoiseOffset != rhs.VertexColorNoiseOffset)
			return VertexColorNoiseOffset < rhs.VertexColorNoiseOffset;

		if (VertexColorNoisePower != rhs.VertexColorNoisePower)
			return VertexColorNoisePower < rhs.VertexColorNoisePower;

		if (UVPosition != rhs.UVPosition)
			return UVPosition < rhs.UVPosition;
		if (UVSize != rhs.UVSize)
			return UVSize < rhs.UVSize;

		return false;
	}

	template <bool T>
	bool Load(BinaryReader<T>& reader, int version)
	{
		reader.Read(Type);

		if (Type == ProceduralModelType::Mesh)
		{
			reader.Read(Mesh.AngleBegin);
			reader.Read(Mesh.AngleEnd);
			reader.Read(Mesh.Divisions);

			if (version >= Version16Alpha9)
			{
				reader.Read(Mesh.Rotate);
			}
		}
		else if (Type == ProceduralModelType::Ribbon)
		{
			reader.Read(Ribbon.CrossSection);
			reader.Read(Ribbon.Rotate);
			reader.Read(Ribbon.Vertices);
			reader.Read(Ribbon.RibbonSizes);
			reader.Read(Ribbon.RibbonAngles);
			reader.Read(Ribbon.RibbonNoises);
			reader.Read(Ribbon.Count);
		}
		else
		{
			assert(0);
		}

		reader.Read(PrimitiveType);

		if (PrimitiveType == ProceduralModelPrimitiveType::Sphere)
		{
			reader.Read(Sphere.Radius);
			reader.Read(Sphere.DepthMin);
			reader.Read(Sphere.DepthMax);
		}
		else if (PrimitiveType == ProceduralModelPrimitiveType::Cone)
		{
			reader.Read(Cone.Radius);
			reader.Read(Cone.Depth);
		}
		else if (PrimitiveType == ProceduralModelPrimitiveType::Cylinder)
		{
			reader.Read(Cylinder.Radius1);
			reader.Read(Cylinder.Radius2);
			reader.Read(Cylinder.Depth);
		}
		else if (PrimitiveType == ProceduralModelPrimitiveType::Spline4)
		{
			reader.Read(Spline4.Point1);
			reader.Read(Spline4.Point2);
			reader.Read(Spline4.Point3);
			reader.Read(Spline4.Point4);
		}

		reader.Read(AxisType);

		reader.Read(TiltNoiseFrequency);
		reader.Read(TiltNoiseOffset);
		reader.Read(TiltNoisePower);

		reader.Read(WaveNoiseFrequency);
		reader.Read(WaveNoiseOffset);
		reader.Read(WaveNoisePower);

		reader.Read(CurlNoiseFrequency);
		reader.Read(CurlNoiseOffset);
		reader.Read(CurlNoisePower);

		reader.Read(ColorUpperLeft);
		reader.Read(ColorUpperCenter);
		reader.Read(ColorUpperRight);

		reader.Read(ColorMiddleLeft);
		reader.Read(ColorMiddleCenter);
		reader.Read(ColorMiddleRight);

		if (version >= Version16Alpha9)
		{
			reader.Read(ColorLowerLeft);
			reader.Read(ColorLowerCenter);
			reader.Read(ColorLowerRight);
		}
		else
		{
			ColorLowerLeft = ColorUpperLeft;
			ColorLowerCenter = ColorUpperCenter;
			ColorLowerRight = ColorUpperRight;
		}

		if (version >= Version16Alpha9)
		{
			reader.Read(ColorCenterPosition);
		}

		reader.Read(ColorCenterArea);

		if (version >= Version16Alpha9)
		{
			reader.Read(VertexColorNoiseFrequency);
			reader.Read(VertexColorNoiseOffset);
			reader.Read(VertexColorNoisePower);
		}
		else
		{
			VertexColorNoiseFrequency.fill(0.0f);
			VertexColorNoiseOffset.fill(0.0f);
			VertexColorNoisePower.fill(0.0f);
		}

		if (version >= Version16Alpha9)
		{
			reader.Read(UVPosition);
			reader.Read(UVSize);
		}

		return true;
	}
};

} // namespace Effekseer

#endif