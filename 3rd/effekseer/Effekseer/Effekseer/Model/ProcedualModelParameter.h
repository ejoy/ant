#ifndef __EFFEKSEER_PROCEDUAL_MODEL_PARAMETER_H__
#define __EFFEKSEER_PROCEDUAL_MODEL_PARAMETER_H__

#include "../Effekseer.Color.h"
#include "../Utils/Effekseer.BinaryReader.h"
#include <stdint.h>
#include <stdio.h>

namespace Effekseer
{

static bool operator==(const std::array<float, 2>& lhs, const std::array<float, 2>& rhs)
{
	for (size_t i = 0; i < lhs.size(); i++)
	{
		if (lhs[i] != rhs[i])
		{
			return false;
		}
	}

	return true;
}

static bool operator<(const std::array<float, 2>& lhs, const std::array<float, 2>& rhs)
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

static bool operator==(const std::array<float, 3>& lhs, const std::array<float, 3>& rhs)
{
	for (size_t i = 0; i < lhs.size(); i++)
	{
		if (lhs[i] != rhs[i])
		{
			return false;
		}
	}

	return true;
}

static bool operator<(const std::array<float, 3>& lhs, const std::array<float, 3>& rhs)
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

enum class ProcedualModelType : int32_t
{
	Mesh,
	Ribbon,
};

enum class ProcedualModelPrimitiveType : int32_t
{
	Sphere,
	Cone,
	Cylinder,
	Spline4,
};

enum class ProcedualModelCrossSectionType : int32_t
{
	Plane,
	Cross,
	Point,
};

enum class ProcedualModelAxisType : int32_t
{
	X,
	Y,
	Z,
};

struct ProcedualModelParameter
{
	ProcedualModelType Type;
	ProcedualModelPrimitiveType PrimitiveType;
	ProcedualModelAxisType AxisType = ProcedualModelAxisType::Y;

	union
	{
		struct
		{
			float AngleBegin;
			float AngleEnd;
			std::array<int, 2> Divisions;
		} Mesh;

		struct
		{
			ProcedualModelCrossSectionType CrossSection;
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

	std::array<float, 2> ColorCenterArea = {0.0f, 0.0f};
	Color ColorLeft;
	Color ColorCenter;
	Color ColorRight;
	Color ColorLeftMiddle;
	Color ColorCenterMiddle;
	Color ColorRightMiddle;

	bool operator<(const ProcedualModelParameter& rhs) const
	{
		if (Type != rhs.Type)
		{
			return static_cast<int32_t>(Type) < static_cast<int32_t>(rhs.Type);
		}

		if (Type == ProcedualModelType::Mesh)
		{
			if (Mesh.AngleBegin != rhs.Mesh.AngleBegin)
				return Mesh.AngleBegin < rhs.Mesh.AngleBegin;

			if (Mesh.AngleEnd != rhs.Mesh.AngleEnd)
				return Mesh.AngleEnd < rhs.Mesh.AngleEnd;

			if (Mesh.Divisions[0] != rhs.Mesh.Divisions[0])
				return Mesh.Divisions[0] < rhs.Mesh.Divisions[0];

			if (Mesh.Divisions[1] != rhs.Mesh.Divisions[1])
				return Mesh.Divisions[1] < rhs.Mesh.Divisions[1];
		}
		else if (Type == ProcedualModelType::Ribbon)
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

		if (PrimitiveType == ProcedualModelPrimitiveType::Sphere)
		{
			if (Sphere.Radius != rhs.Sphere.Radius)
				return Sphere.Radius < rhs.Sphere.Radius;

			if (Sphere.DepthMin != rhs.Sphere.DepthMin)
				return Sphere.DepthMax < rhs.Sphere.DepthMax;
		}
		else if (PrimitiveType == ProcedualModelPrimitiveType::Cone)
		{
			if (Cone.Radius != rhs.Cone.Radius)
				return Cone.Radius < rhs.Cone.Radius;

			if (Cone.Depth != rhs.Cone.Depth)
				return Cone.Depth < rhs.Cone.Depth;
		}
		else if (PrimitiveType == ProcedualModelPrimitiveType::Cylinder)
		{
			if (Cylinder.Radius1 != rhs.Cylinder.Radius1)
				return Cylinder.Radius1 < rhs.Cylinder.Radius1;

			if (Cylinder.Radius2 != rhs.Cylinder.Radius2)
				return Cylinder.Radius2 < rhs.Cylinder.Radius2;

			if (Cylinder.Depth != rhs.Cylinder.Depth)
				return Cylinder.Depth < rhs.Cylinder.Depth;
		}
		else if (PrimitiveType == ProcedualModelPrimitiveType::Spline4)
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

		if (ColorLeft != rhs.ColorLeft)
			return ColorLeft < rhs.ColorLeft;

		if (ColorCenter != rhs.ColorCenter)
			return ColorCenter < rhs.ColorCenter;

		if (ColorRight != rhs.ColorRight)
			return ColorRight < rhs.ColorRight;

		if (ColorLeftMiddle != rhs.ColorLeftMiddle)
			return ColorLeftMiddle < rhs.ColorLeftMiddle;

		if (ColorCenterMiddle != rhs.ColorCenterMiddle)
			return ColorCenterMiddle < rhs.ColorCenterMiddle;

		if (ColorRightMiddle != rhs.ColorRightMiddle)
			return ColorRightMiddle < rhs.ColorRightMiddle;

		if (ColorCenterArea != rhs.ColorCenterArea)
			return ColorCenterArea < rhs.ColorCenterArea;

		return false;
	}

	template <bool T>
	bool Load(BinaryReader<T>& reader)
	{
		reader.Read(Type);

		if (Type == ProcedualModelType::Mesh)
		{
			reader.Read(Mesh.AngleBegin);
			reader.Read(Mesh.AngleEnd);
			reader.Read(Mesh.Divisions);
		}
		else if (Type == ProcedualModelType::Ribbon)
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

		if (PrimitiveType == ProcedualModelPrimitiveType::Sphere)
		{
			reader.Read(Sphere.Radius);
			reader.Read(Sphere.DepthMin);
			reader.Read(Sphere.DepthMax);
		}
		else if (PrimitiveType == ProcedualModelPrimitiveType::Cone)
		{
			reader.Read(Cone.Radius);
			reader.Read(Cone.Depth);
		}
		else if (PrimitiveType == ProcedualModelPrimitiveType::Cylinder)
		{
			reader.Read(Cylinder.Radius1);
			reader.Read(Cylinder.Radius2);
			reader.Read(Cylinder.Depth);
		}
		else if (PrimitiveType == ProcedualModelPrimitiveType::Spline4)
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

		reader.Read(ColorLeft);
		reader.Read(ColorCenter);
		reader.Read(ColorRight);
		reader.Read(ColorLeftMiddle);
		reader.Read(ColorCenterMiddle);
		reader.Read(ColorRightMiddle);
		reader.Read(ColorCenterArea);

		return true;
	}
};

} // namespace Effekseer

#endif