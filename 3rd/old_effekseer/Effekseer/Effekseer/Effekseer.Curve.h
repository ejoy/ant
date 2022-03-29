
#ifndef __EFFEKSEER_CURVE_H__
#define __EFFEKSEER_CURVE_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include "Effekseer.Base.h"
#include "Effekseer.Manager.h"
#include "Effekseer.Resource.h"
#include "Effekseer.Vector3D.h"

#include <cmath>
#include <limits>
#include <vector>

namespace Effekseer
{

class dVector4
{
public:
	double X, Y, Z, W;

public:
	dVector4(double x = 0, double y = 0, double z = 0, double w = 0)
		: X(x)
		, Y(y)
		, Z(z)
		, W(w)
	{
	}
};

/**
@brief
\~English	Curve class
\~Japanese	カーブクラス
*/
class Curve : public Resource
{
	friend class CurveLoader;

public:
	static const int32_t Version = 1;

private:
	int mControllPointCount;
	std::vector<dVector4> mControllPoint;

	int mKnotCount;
	std::vector<double> mKnotValue;

	int mOrder;
	int mStep;
	int mType;
	int mDimension;

	float mLength;

private:
	/**
	 * CalcBSplineBasisFunc : B-スプライン基底関数の計算
	 * 
	 * const vector<double>& knot : ノット列
	 * unsigned int j : ノット列の開始番号
	 * unsigned int p : 次数
	 * double t : 計算対象の独立変数
	 * 
	 * ノット列は昇順である必要があるが、そのチェックは行わない
	 * 
	 * 戻り値 : 計算結果
	 */
	double CalcBSplineBasisFunc(const std::vector<double>& knot, unsigned int j, unsigned int p, double t)
	{
		if (knot.size() == 0)
			return std::numeric_limits<double>::quiet_NaN();

		// ノット列のデータ長が充分でない場合は nan を返す
		unsigned int m = static_cast<unsigned int>(knot.size()) - 1;
		if (m < j + p + 1)
			return std::numeric_limits<double>::quiet_NaN();

		// 正値をとる範囲外ならゼロを返す
		if ((t < knot[j]) || (t > knot[j + p + 1]))
			return (0);
		// p = 0 かつ knot[j] <= t <= knot[j + p + 1] なら 1 を返す
		if (p == 0)
			return (1);
		// p = 1 の場合、三角の頂点の値は特別扱い
		if (p == 1 && t == knot[j + 1])
			return (1);

		// 漸化式の計算
		double d1 = (knot[j + p] == knot[j]) ? 0 : (t - knot[j]) * CalcBSplineBasisFunc(knot, j, p - 1, t) / (knot[j + p] - knot[j]);
		double d2 = (knot[j + p + 1] == knot[j + 1]) ? 0 : (knot[j + p + 1] - t) * CalcBSplineBasisFunc(knot, j + 1, p - 1, t) / (knot[j + p + 1] - knot[j + 1]);

		return (d1 + d2);
	}

public:
	Curve()
	{
	}

	Curve(const void* data, int32_t size)
	{
		uint8_t* pData = new uint8_t[size];
		memcpy(pData, data, size);

		uint8_t* p = (uint8_t*)pData;

		// load converter version
		int converter_version = 0;
		memcpy(&converter_version, p, sizeof(int32_t));
		p += sizeof(int32_t);

		// load controll point count
		memcpy(&mControllPointCount, p, sizeof(int32_t));
		p += sizeof(int32_t);

		// load controll points
		for (int i = 0; i < mControllPointCount; i++)
		{
			dVector4 value;
			memcpy(&value, p, sizeof(dVector4));
			p += sizeof(dVector4);
			mControllPoint.push_back(value);
		}

		// load knot count
		memcpy(&mKnotCount, p, sizeof(int32_t));
		p += sizeof(int32_t);

		// load knot values
		for (int i = 0; i < mKnotCount; i++)
		{
			double value;
			memcpy(&value, p, sizeof(double));
			p += sizeof(double);
			mKnotValue.push_back(value);
		}

		// load order
		memcpy(&mOrder, p, sizeof(int32_t));
		p += sizeof(int32_t);

		// load step
		memcpy(&mStep, p, sizeof(int32_t));
		p += sizeof(int32_t);

		// load type
		memcpy(&mType, p, sizeof(int32_t));
		p += sizeof(int32_t);

		// load dimension
		memcpy(&mDimension, p, sizeof(int32_t));
		p += sizeof(int32_t);

		// calc curve length
		mLength = 0;

		for (int i = 1; i < mControllPointCount; i++)
		{
			dVector4 p0 = mControllPoint[i - 1];
			dVector4 p1 = mControllPoint[i];

			float len = Vector3D::Length(Vector3D((float)p1.X, (float)p1.Y, (float)p1.Z) - Vector3D((float)p0.X, (float)p0.Y, (float)p0.Z));
			mLength += len;
		}

		ES_SAFE_DELETE_ARRAY(pData);
	}

	~Curve()
	{
	}

	Vector3D CalcuratePoint(float t, float magnification)
	{
		if (t == 0.0f && mControllPoint.size() > 0)
		{
			return {
				static_cast<float>(mControllPoint[0].X * magnification),
				static_cast<float>(mControllPoint[0].Y * magnification),
				static_cast<float>(mControllPoint[0].Z * magnification)};
		}

		int p = mOrder; // 次数

		std::vector<double> bs(mControllPointCount); // B-Spline 基底関数の計算結果(重み値を積算)

		// ノット列の要素を +1 する
		auto knot = mKnotValue;
		knot.push_back(mKnotValue[mKnotValue.size() - 1] + 1);

		float t_rate = float(knot.back() - 1);

		double wSum = 0; // bs の合計
		for (int j = 0; j < mControllPointCount; ++j)
		{
			bs[j] = mControllPoint[j].W * CalcBSplineBasisFunc(knot, j, p, t * (t_rate));

			if (!std::isnan(bs[j]))
			{
				wSum += bs[j];
			}
		}

		Vector3D ans(0, 0, 0); // 計算結果
		for (int j = 0; j < mControllPointCount; ++j)
		{
			Vector3D d;
			d.X = (float)mControllPoint[j].X * magnification * (float)bs[j] / (float)wSum;
			d.Y = (float)mControllPoint[j].Y * magnification * (float)bs[j] / (float)wSum;
			d.Z = (float)mControllPoint[j].Z * magnification * (float)bs[j] / (float)wSum;
			if (!std::isnan(d.X) && !std::isnan(d.Y) && !std::isnan(d.Z))
			{
				ans += d;
			}
		}

		return ans;
	}

	//
	//  Getter
	//
	int GetControllPointCount()
	{
		return mControllPointCount;
	}
	dVector4 GetControllPoint(int index)
	{
		return mControllPoint[index];
	}

	int GetKnotCount()
	{
		return mKnotCount;
	}
	double GetKnotValue(int index)
	{
		return mKnotValue[index];
	}

	int GetOrder()
	{
		return mOrder;
	}
	int GetStep()
	{
		return mStep;
	}
	int GetType()
	{
		return mType;
	}
	int GetDimension()
	{
		return mDimension;
	}

	float GetLength()
	{
		return mLength;
	}

}; // end class

} // end namespace Effekseer

#endif // __EFFEKSEER_CURVE_H__
