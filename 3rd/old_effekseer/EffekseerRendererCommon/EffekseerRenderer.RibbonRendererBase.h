
#ifndef __EFFEKSEERRENDERER_RIBBON_RENDERER_BASE_H__
#define __EFFEKSEERRENDERER_RIBBON_RENDERER_BASE_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include <Effekseer.h>
#include <assert.h>
#include <string.h>

#include "EffekseerRenderer.CommonUtils.h"
#include "EffekseerRenderer.IndexBufferBase.h"
#include "EffekseerRenderer.RenderStateBase.h"
#include "EffekseerRenderer.StandardRenderer.h"
#include "EffekseerRenderer.VertexBufferBase.h"

//-----------------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------------
namespace EffekseerRenderer
{
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
typedef ::Effekseer::RibbonRenderer::NodeParameter efkRibbonNodeParam;
typedef ::Effekseer::RibbonRenderer::InstanceParameter efkRibbonInstanceParam;
typedef ::Effekseer::SIMD::Vec3f efkVector3D;

template <typename RENDERER, bool FLIP_RGB_FLAG>
class RibbonRendererBase : public ::Effekseer::RibbonRenderer, public ::Effekseer::SIMD::AlignedAllocationPolicy<16>
{
private:
protected:
	RENDERER* m_renderer;
	int32_t m_ribbonCount;

	int32_t m_ringBufferOffset;
	uint8_t* m_ringBufferData;

	efkRibbonNodeParam innstancesNodeParam;
	Effekseer::CustomAlignedVector<efkRibbonInstanceParam> instances;
	Effekseer::SplineGenerator spline_left;
	Effekseer::SplineGenerator spline_right;

	int32_t vertexCount_ = 0;
	int32_t stride_ = 0;

	int32_t customData1Count_ = 0;
	int32_t customData2Count_ = 0;

	template <typename VERTEX, int TARGET>
	void AssignUV(StrideView<VERTEX> v, float uvX1, float uvX2, float uvY1, float uvY2)
	{
		if (TARGET == 0)
		{
			v[0].UV[0] = uvX1;
			v[0].UV[1] = uvY1;

			v[1].UV[0] = uvX2;
			v[1].UV[1] = uvY1;

			v[2].UV[0] = uvX1;
			v[2].UV[1] = uvY2;

			v[3].UV[0] = uvX2;
			v[3].UV[1] = uvY2;
		}
		else if (TARGET == 1)
		{
			v[0].UV2[0] = uvX1;
			v[0].UV2[1] = uvY1;

			v[1].UV2[0] = uvX2;
			v[1].UV2[1] = uvY1;

			v[2].UV2[0] = uvX1;
			v[2].UV2[1] = uvY2;

			v[3].UV2[0] = uvX2;
			v[3].UV2[1] = uvY2;
		}
		else if (TARGET == 2)
		{
			SetVertexAlphaUV(v[0], uvX1, 0);
			SetVertexAlphaUV(v[0], uvY1, 1);

			SetVertexAlphaUV(v[1], uvX2, 0);
			SetVertexAlphaUV(v[1], uvY1, 1);

			SetVertexAlphaUV(v[2], uvX1, 0);
			SetVertexAlphaUV(v[2], uvY2, 1);

			SetVertexAlphaUV(v[3], uvX2, 0);
			SetVertexAlphaUV(v[3], uvY2, 1);
		}
		else if (TARGET == 3)
		{
			SetVertexUVDistortionUV(v[0], uvX1, 0);
			SetVertexUVDistortionUV(v[0], uvY1, 1);

			SetVertexUVDistortionUV(v[1], uvX2, 0);
			SetVertexUVDistortionUV(v[1], uvY1, 1);

			SetVertexUVDistortionUV(v[2], uvX1, 0);
			SetVertexUVDistortionUV(v[2], uvY2, 1);

			SetVertexUVDistortionUV(v[3], uvX2, 0);
			SetVertexUVDistortionUV(v[3], uvY2, 1);
		}
		else if (TARGET == 4)
		{
			SetVertexBlendUV(v[0], uvX1, 0);
			SetVertexBlendUV(v[0], uvY1, 1);

			SetVertexBlendUV(v[1], uvX2, 0);
			SetVertexBlendUV(v[1], uvY1, 1);

			SetVertexBlendUV(v[2], uvX1, 0);
			SetVertexBlendUV(v[2], uvY2, 1);

			SetVertexBlendUV(v[3], uvX2, 0);
			SetVertexBlendUV(v[3], uvY2, 1);
		}
		else if (TARGET == 5)
		{
			SetVertexBlendAlphaUV(v[0], uvX1, 0);
			SetVertexBlendAlphaUV(v[0], uvY1, 1);

			SetVertexBlendAlphaUV(v[1], uvX2, 0);
			SetVertexBlendAlphaUV(v[1], uvY1, 1);

			SetVertexBlendAlphaUV(v[2], uvX1, 0);
			SetVertexBlendAlphaUV(v[2], uvY2, 1);

			SetVertexBlendAlphaUV(v[3], uvX2, 0);
			SetVertexBlendAlphaUV(v[3], uvY2, 1);
		}
		else if (TARGET == 6)
		{
			SetVertexBlendUVDistortionUV(v[0], uvX1, 0);
			SetVertexBlendUVDistortionUV(v[0], uvY1, 1);

			SetVertexBlendUVDistortionUV(v[1], uvX2, 0);
			SetVertexBlendUVDistortionUV(v[1], uvY1, 1);

			SetVertexBlendUVDistortionUV(v[2], uvX1, 0);
			SetVertexBlendUVDistortionUV(v[2], uvY2, 1);

			SetVertexBlendUVDistortionUV(v[3], uvX2, 0);
			SetVertexBlendUVDistortionUV(v[3], uvY2, 1);
		}
	}

	template <typename VERTEX, int TARGET>
	void AssignUVs(efkRibbonNodeParam& parameter, StrideView<VERTEX> verteies)
	{
		float uvx = 0.0f;
		float uvw = 1.0f;
		float uvy = 0.0f;
		float uvh = 1.0f;

		if (parameter.TextureUVTypeParameterPtr->Type == ::Effekseer::TextureUVType::Strech)
		{
			verteies.Reset();

			for (size_t loop = 0; loop < instances.size() - 1; loop++)
			{
				const auto& param = instances[loop];
				if (TARGET == 0)
				{
					uvx = param.UV.X;
					uvw = param.UV.Width;
					uvy = param.UV.Y;
					uvh = param.UV.Height;
				}
				else if (TARGET == 2)
				{
					uvx = param.AlphaUV.X;
					uvw = param.AlphaUV.Width;
					uvy = param.AlphaUV.Y;
					uvh = param.AlphaUV.Height;
				}
				else if (TARGET == 3)
				{
					uvx = param.UVDistortionUV.X;
					uvw = param.UVDistortionUV.Width;
					uvy = param.UVDistortionUV.Y;
					uvh = param.UVDistortionUV.Height;
				}
				else if (TARGET == 4)
				{
					uvx = param.BlendUV.X;
					uvw = param.BlendUV.Width;
					uvy = param.BlendUV.Y;
					uvh = param.BlendUV.Height;
				}
				else if (TARGET == 5)
				{
					uvx = param.BlendAlphaUV.X;
					uvw = param.BlendAlphaUV.Width;
					uvy = param.BlendAlphaUV.Y;
					uvh = param.BlendAlphaUV.Height;
				}
				else if (TARGET == 6)
				{
					uvx = param.BlendUVDistortionUV.X;
					uvw = param.BlendUVDistortionUV.Width;
					uvy = param.BlendUVDistortionUV.Y;
					uvh = param.BlendUVDistortionUV.Height;
				}

				for (int32_t sploop = 0; sploop < parameter.SplineDivision; sploop++)
				{
					float percent1 = (float)(param.InstanceIndex * parameter.SplineDivision + sploop) /
									 (float)((param.InstanceCount - 1) * parameter.SplineDivision);

					float percent2 = (float)(param.InstanceIndex * parameter.SplineDivision + sploop + 1) /
									 (float)((param.InstanceCount - 1) * parameter.SplineDivision);

					auto uvX1 = uvx;
					auto uvX2 = uvx + uvw;
					auto uvY1 = uvy + percent1 * uvh;
					auto uvY2 = uvy + percent2 * uvh;

					AssignUV<VERTEX, TARGET>(verteies, uvX1, uvX2, uvY1, uvY2);

					verteies += 4;
				}
			}
		}
		else if (parameter.TextureUVTypeParameterPtr->Type == ::Effekseer::TextureUVType::Tile)
		{
			const auto& uvParam = *parameter.TextureUVTypeParameterPtr;

			verteies.Reset();

			for (size_t loop = 0; loop < instances.size() - 1; loop++)
			{
				auto& param = instances[loop];
				if (TARGET == 0)
				{
					uvx = param.UV.X;
					uvw = param.UV.Width;
					uvy = param.UV.Y;
					uvh = param.UV.Height;
				}
				else if (TARGET == 2)
				{
					uvx = param.AlphaUV.X;
					uvw = param.AlphaUV.Width;
					uvy = param.AlphaUV.Y;
					uvh = param.AlphaUV.Height;
				}
				else if (TARGET == 3)
				{
					uvx = param.UVDistortionUV.X;
					uvw = param.UVDistortionUV.Width;
					uvy = param.UVDistortionUV.Y;
					uvh = param.UVDistortionUV.Height;
				}
				else if (TARGET == 4)
				{
					uvx = param.BlendUV.X;
					uvw = param.BlendUV.Width;
					uvy = param.BlendUV.Y;
					uvh = param.BlendUV.Height;
				}
				else if (TARGET == 5)
				{
					uvx = param.BlendAlphaUV.X;
					uvw = param.BlendAlphaUV.Width;
					uvy = param.BlendAlphaUV.Y;
					uvh = param.BlendAlphaUV.Height;
				}
				else if (TARGET == 6)
				{
					uvx = param.BlendUVDistortionUV.X;
					uvw = param.BlendUVDistortionUV.Width;
					uvy = param.BlendUVDistortionUV.Y;
					uvh = param.BlendUVDistortionUV.Height;
				}

				if (loop < uvParam.TileEdgeTail)
				{
					float uvBegin = uvy;
					float uvEnd = uvy + uvh * uvParam.TileLoopAreaBegin;

					for (int32_t sploop = 0; sploop < parameter.SplineDivision; sploop++)
					{
						float percent1 = (float)(param.InstanceIndex * parameter.SplineDivision + sploop) /
										 (float)((uvParam.TileEdgeTail) * parameter.SplineDivision);

						float percent2 = (float)(param.InstanceIndex * parameter.SplineDivision + sploop + 1) /
										 (float)((uvParam.TileEdgeTail) * parameter.SplineDivision);

						auto uvX1 = uvx;
						auto uvX2 = uvx + uvw;
						auto uvY1 = uvBegin + (uvEnd - uvBegin) * percent1;
						auto uvY2 = uvBegin + (uvEnd - uvBegin) * percent2;

						AssignUV<VERTEX, TARGET>(verteies, uvX1, uvX2, uvY1, uvY2);

						verteies += 4;
					}
				}
				else if (loop >= param.InstanceCount - 1 - uvParam.TileEdgeHead)
				{
					float uvBegin = uvy + uvh * uvParam.TileLoopAreaEnd;
					float uvEnd = uvy + uvh * 1.0f;

					for (int32_t sploop = 0; sploop < parameter.SplineDivision; sploop++)
					{
						float percent1 =
							(float)((param.InstanceIndex - (param.InstanceCount - 1 - uvParam.TileEdgeHead)) * parameter.SplineDivision +
									sploop) /
							(float)((uvParam.TileEdgeHead) * parameter.SplineDivision);

						float percent2 =
							(float)((param.InstanceIndex - (param.InstanceCount - 1 - uvParam.TileEdgeHead)) * parameter.SplineDivision +
									sploop + 1) /
							(float)((uvParam.TileEdgeHead) * parameter.SplineDivision);

						auto uvX1 = uvx;
						auto uvX2 = uvx + uvw;
						auto uvY1 = uvBegin + (uvEnd - uvBegin) * percent1;
						auto uvY2 = uvBegin + (uvEnd - uvBegin) * percent2;

						AssignUV<VERTEX, TARGET>(verteies, uvX1, uvX2, uvY1, uvY2);

						verteies += 4;
					}
				}
				else
				{
					float uvBegin = uvy + uvh * uvParam.TileLoopAreaBegin;
					float uvEnd = uvy + uvh * uvParam.TileLoopAreaEnd;

					for (int32_t sploop = 0; sploop < parameter.SplineDivision; sploop++)
					{
						float percent1 = (float)(sploop) / (float)(parameter.SplineDivision);

						float percent2 = (float)(sploop + 1) / (float)(parameter.SplineDivision);

						auto uvX1 = uvx;
						auto uvX2 = uvx + uvw;
						auto uvY1 = uvBegin + (uvEnd - uvBegin) * percent1;
						auto uvY2 = uvBegin + (uvEnd - uvBegin) * percent2;

						AssignUV<VERTEX, TARGET>(verteies, uvX1, uvX2, uvY1, uvY2);

						verteies += 4;
					}
				}
			}
		}
	}

	template <typename VERTEX, bool FLIP_RGB>
	void RenderSplines(const ::Effekseer::SIMD::Mat44f& camera)
	{
		if (instances.size() == 0)
		{
			return;
		}

		auto& parameter = innstancesNodeParam;

		// Calculate spline
		if (parameter.SplineDivision > 1)
		{
			spline_left.Reset();
			spline_right.Reset();

			for (size_t loop = 0; loop < instances.size(); loop++)
			{
				auto& param = instances[loop];

				efkVector3D pl(param.Positions[0], 0.0f, 0.0f);
				efkVector3D pr(param.Positions[1], 0.0f, 0.0f);

				if (parameter.ViewpointDependent)
				{
					::Effekseer::SIMD::Mat43f mat = param.SRTMatrix43;

					if (parameter.EnableViewOffset == true)
					{
						ApplyViewOffset(mat, camera, param.ViewOffsetDistance);
					}

					::Effekseer::SIMD::Vec3f s;
					::Effekseer::SIMD::Mat43f r;
					::Effekseer::SIMD::Vec3f t;
					mat.GetSRT(s, r, t);

					ApplyDepthParameters(r,
										 t,
										 s,
										 m_renderer->GetCameraFrontDirection(),
										 m_renderer->GetCameraPosition(),
										 parameter.DepthParameterPtr,
										 parameter.IsRightHand);

					// extend
					pl.SetX(pl.GetX() * s.GetX());
					pr.SetX(pr.GetX() * s.GetX());

					::Effekseer::SIMD::Vec3f F;
					::Effekseer::SIMD::Vec3f R;
					::Effekseer::SIMD::Vec3f U;

					U = ::Effekseer::SIMD::Vec3f(r.X.GetY(), r.Y.GetY(), r.X.GetY());
					F = ::Effekseer::SIMD::Vec3f(-m_renderer->GetCameraFrontDirection()).Normalize();
					R = ::Effekseer::SIMD::Vec3f::Cross(U, F).Normalize();
					F = ::Effekseer::SIMD::Vec3f::Cross(R, U).Normalize();

					::Effekseer::SIMD::Mat43f mat_rot(-R.GetX(),
													  -R.GetY(),
													  -R.GetZ(),
													  U.GetX(),
													  U.GetY(),
													  U.GetZ(),
													  F.GetX(),
													  F.GetY(),
													  F.GetZ(),
													  t.GetX(),
													  t.GetY(),
													  t.GetZ());

					pl = ::Effekseer::SIMD::Vec3f::Transform(pl, mat_rot);
					pr = ::Effekseer::SIMD::Vec3f::Transform(pr, mat_rot);

					spline_left.AddVertex(pl);
					spline_right.AddVertex(pr);
				}
				else
				{
					::Effekseer::SIMD::Mat43f mat = param.SRTMatrix43;

					if (parameter.EnableViewOffset == true)
					{
						ApplyViewOffset(mat, camera, param.ViewOffsetDistance);
					}

					ApplyDepthParameters(mat,
										 m_renderer->GetCameraFrontDirection(),
										 m_renderer->GetCameraPosition(),
										 // s,
										 parameter.DepthParameterPtr,
										 parameter.IsRightHand);

					pl = ::Effekseer::SIMD::Vec3f::Transform(pl, mat);
					pr = ::Effekseer::SIMD::Vec3f::Transform(pr, mat);

					spline_left.AddVertex(pl);
					spline_right.AddVertex(pr);
				}
			}

			spline_left.Calculate();
			spline_right.Calculate();
		}

		StrideView<VERTEX> verteies(m_ringBufferData, stride_, vertexCount_);
		for (size_t loop = 0; loop < instances.size(); loop++)
		{
			auto& param = instances[loop];

			for (auto sploop = 0; sploop < parameter.SplineDivision; sploop++)
			{
				bool isFirst = param.InstanceIndex == 0 && sploop == 0;
				bool isLast = param.InstanceIndex == (param.InstanceCount - 1);

				float percent_instance = sploop / (float)parameter.SplineDivision;

				if (parameter.SplineDivision > 1)
				{
					verteies[0].Pos = ToStruct(spline_left.GetValue(param.InstanceIndex + sploop / (float)parameter.SplineDivision));
					verteies[1].Pos = ToStruct(spline_right.GetValue(param.InstanceIndex + sploop / (float)parameter.SplineDivision));

					verteies[0].SetColor(Effekseer::Color::Lerp(param.Colors[0], param.Colors[2], percent_instance), FLIP_RGB);
					verteies[1].SetColor(Effekseer::Color::Lerp(param.Colors[1], param.Colors[3], percent_instance), FLIP_RGB);
				}
				else
				{
					for (int i = 0; i < 2; i++)
					{
						verteies[i].Pos.X = param.Positions[i];
						verteies[i].Pos.Y = 0.0f;
						verteies[i].Pos.Z = 0.0f;
						verteies[i].SetColor(param.Colors[i], FLIP_RGB);
						verteies[i].SetFlipbookIndexAndNextRate(param.FlipbookIndexAndNextRate);
						verteies[i].SetAlphaThreshold(param.AlphaThreshold);
					}
				}

				if (parameter.ViewpointDependent)
				{
					::Effekseer::SIMD::Mat43f mat = param.SRTMatrix43;

					if (parameter.EnableViewOffset == true)
					{
						ApplyViewOffset(mat, camera, param.ViewOffsetDistance);
					}

					::Effekseer::SIMD::Vec3f s;
					::Effekseer::SIMD::Mat43f r;
					::Effekseer::SIMD::Vec3f t;
					mat.GetSRT(s, r, t);

					ApplyDepthParameters(r,
										 t,
										 s,
										 m_renderer->GetCameraFrontDirection(),
										 m_renderer->GetCameraPosition(),
										 parameter.DepthParameterPtr,
										 parameter.IsRightHand);

					if (parameter.SplineDivision > 1)
					{
					}
					else
					{
						for (int i = 0; i < 2; i++)
						{
							verteies[i].Pos.X = verteies[i].Pos.X * s.GetX();
						}

						::Effekseer::SIMD::Vec3f F;
						::Effekseer::SIMD::Vec3f R;
						::Effekseer::SIMD::Vec3f U;

						U = ::Effekseer::SIMD::Vec3f(r.X.GetY(), r.Y.GetY(), r.Z.GetY());

						F = ::Effekseer::SIMD::Vec3f(-m_renderer->GetCameraFrontDirection()).Normalize();
						R = ::Effekseer::SIMD::Vec3f::Cross(U, F).Normalize();
						F = ::Effekseer::SIMD::Vec3f::Cross(R, U).Normalize();

						::Effekseer::SIMD::Mat43f mat_rot(-R.GetX(),
														  -R.GetY(),
														  -R.GetZ(),
														  U.GetX(),
														  U.GetY(),
														  U.GetZ(),
														  F.GetX(),
														  F.GetY(),
														  F.GetZ(),
														  t.GetX(),
														  t.GetY(),
														  t.GetZ());

						for (int i = 0; i < 2; i++)
						{
							verteies[i].Pos = ToStruct(::Effekseer::SIMD::Vec3f::Transform(verteies[i].Pos, mat_rot));
						}
					}
				}
				else
				{
					if (parameter.SplineDivision > 1)
					{
					}
					else
					{
						::Effekseer::SIMD::Mat43f mat = param.SRTMatrix43;

						if (parameter.EnableViewOffset == true)
						{
							ApplyViewOffset(mat, camera, param.ViewOffsetDistance);
						}

						ApplyDepthParameters(mat,
											 m_renderer->GetCameraFrontDirection(),
											 m_renderer->GetCameraPosition(),
											 // s,
											 parameter.DepthParameterPtr,
											 parameter.IsRightHand);

						for (int i = 0; i < 2; i++)
						{
							verteies[i].Pos = ToStruct(::Effekseer::SIMD::Vec3f::Transform(verteies[i].Pos, mat));
						}
					}
				}

				if (isFirst || isLast)
				{
					verteies += 2;
				}
				else
				{
					verteies[2] = verteies[0];
					verteies[3] = verteies[1];
					verteies += 4;
				}

				if (!isFirst)
				{
					m_ribbonCount++;
				}

				if (isLast)
				{
					break;
				}
			}
		}

		// calculate UV
		AssignUVs<VERTEX, 0>(parameter, verteies);

		if (VertexUV2Required<VERTEX>())
		{
			AssignUVs<VERTEX, 1>(parameter, verteies);
		}

		AssignUVs<VERTEX, 2>(parameter, verteies);
		AssignUVs<VERTEX, 3>(parameter, verteies);
		AssignUVs<VERTEX, 4>(parameter, verteies);
		AssignUVs<VERTEX, 5>(parameter, verteies);
		AssignUVs<VERTEX, 6>(parameter, verteies);

		if (VertexNormalRequired<VERTEX>())
		{
			StrideView<VERTEX> vs_(m_ringBufferData, stride_, vertexCount_);
			Effekseer::SIMD::Vec3f axisBefore{};

			for (size_t i = 0; i < (instances.size() - 1) * parameter.SplineDivision + 1; i++)
			{
				bool isFirst_ = (i == 0);
				bool isLast_ = (i == ((instances.size() - 1) * parameter.SplineDivision));

				Effekseer::SIMD::Vec3f axis;

				if (isFirst_)
				{
					axis = (vs_[3].Pos - vs_[1].Pos);
					axis = SafeNormalize(axis);
					axisBefore = axis;
				}
				else if (isLast_)
				{
					axis = axisBefore;
				}
				else
				{
					Effekseer::SIMD::Vec3f axisOld = axisBefore;
					axis = (vs_[5].Pos - vs_[3].Pos);
					axis = SafeNormalize(axis);
					axisBefore = axis;

					axis = (axisBefore + axisOld) / 2.0f;
					axis = SafeNormalize(axis);
				}

				Effekseer::SIMD::Vec3f tangent = vs_[1].Pos - vs_[0].Pos;
				tangent = SafeNormalize(tangent);

				Effekseer::SIMD::Vec3f normal = Effekseer::SIMD::Vec3f::Cross(axis, tangent);
				normal = SafeNormalize(normal);

				if (!parameter.IsRightHand)
				{
					normal = -normal;
				}

				if (isFirst_)
				{
					const auto packedNormal = PackVector3DF(normal);
					const auto packedTangent = PackVector3DF(tangent);
					vs_[0].SetPackedNormal(packedNormal);
					vs_[0].SetPackedTangent(packedTangent);
					vs_[1].SetPackedNormal(packedNormal);
					vs_[1].SetPackedTangent(packedTangent);

					vs_ += 2;
				}
				else if (isLast_)
				{
					const auto packedNormal = PackVector3DF(normal);
					const auto packedTangent = PackVector3DF(tangent);
					vs_[0].SetPackedNormal(packedNormal);
					vs_[0].SetPackedTangent(packedTangent);
					vs_[1].SetPackedNormal(packedNormal);
					vs_[1].SetPackedTangent(packedTangent);

					vs_ += 2;
				}
				else
				{
					const auto packedNormal = PackVector3DF(normal);
					const auto packedTangent = PackVector3DF(tangent);
					vs_[0].SetPackedNormal(packedNormal);
					vs_[0].SetPackedTangent(packedTangent);
					vs_[1].SetPackedNormal(packedNormal);
					vs_[1].SetPackedTangent(packedTangent);
					vs_[2].SetPackedNormal(packedNormal);
					vs_[2].SetPackedTangent(packedTangent);
					vs_[3].SetPackedNormal(packedNormal);
					vs_[3].SetPackedTangent(packedTangent);

					vs_ += 4;
				}
			}
		}

		// custom parameter
		if (customData1Count_ > 0)
		{
			StrideView<float> custom(m_ringBufferData + sizeof(DynamicVertex), stride_, vertexCount_);
			for (size_t loop = 0; loop < instances.size() - 1; loop++)
			{
				auto& param = instances[loop];

				for (int32_t sploop = 0; sploop < parameter.SplineDivision; sploop++)
				{
					for (size_t i = 0; i < 4; i++)
					{
						auto c = (float*)(&custom[0]);
						memcpy(c, param.CustomData1.data(), sizeof(float) * customData1Count_);
						custom += 1;
					}
				}
			}
		}

		if (customData2Count_ > 0)
		{
			StrideView<float> custom(m_ringBufferData + sizeof(DynamicVertex) + sizeof(float) * customData1Count_, stride_, vertexCount_);
			for (size_t loop = 0; loop < instances.size() - 1; loop++)
			{
				auto& param = instances[loop];

				for (int32_t sploop = 0; sploop < parameter.SplineDivision; sploop++)
				{
					for (size_t i = 0; i < 4; i++)
					{
						auto c = (float*)(&custom[0]);
						memcpy(c, param.CustomData2.data(), sizeof(float) * customData2Count_);
						custom += 1;
					}
				}
			}
		}
	}

public:
	RibbonRendererBase(RENDERER* renderer)
		: m_renderer(renderer)
		, m_ribbonCount(0)
		, m_ringBufferOffset(0)
		, m_ringBufferData(nullptr)
	{
	}

	virtual ~RibbonRendererBase()
	{
	}

protected:
	void Rendering_(const efkRibbonNodeParam& parameter,
					const efkRibbonInstanceParam& instanceParameter,
					const ::Effekseer::SIMD::Mat44f& camera)
	{
		const auto& state = m_renderer->GetStandardRenderer()->GetState();
		const ShaderParameterCollector& collector = state.Collector;
		if (collector.ShaderType == RendererShaderType::Material)
		{
			Rendering_Internal<DynamicVertex, FLIP_RGB_FLAG>(parameter, instanceParameter, camera);
		}
		else if (collector.ShaderType == RendererShaderType::AdvancedLit)
		{
			Rendering_Internal<AdvancedLightingVertex, FLIP_RGB_FLAG>(parameter, instanceParameter, camera);
		}
		else if (collector.ShaderType == RendererShaderType::AdvancedBackDistortion)
		{
			Rendering_Internal<AdvancedLightingVertex, FLIP_RGB_FLAG>(parameter, instanceParameter, camera);
		}
		else if (collector.ShaderType == RendererShaderType::AdvancedUnlit)
		{
			Rendering_Internal<AdvancedSimpleVertex, FLIP_RGB_FLAG>(parameter, instanceParameter, camera);
		}
		else if (collector.ShaderType == RendererShaderType::Lit)
		{
			Rendering_Internal<LightingVertex, FLIP_RGB_FLAG>(parameter, instanceParameter, camera);
		}
		else if (collector.ShaderType == RendererShaderType::BackDistortion)
		{
			Rendering_Internal<LightingVertex, FLIP_RGB_FLAG>(parameter, instanceParameter, camera);
		}
		else
		{
			Rendering_Internal<SimpleVertex, FLIP_RGB_FLAG>(parameter, instanceParameter, camera);
		}
	}

	template <typename VERTEX, bool FLIP_RGB>
	void Rendering_Internal(const efkRibbonNodeParam& parameter,
							const efkRibbonInstanceParam& instanceParameter,
							const ::Effekseer::SIMD::Mat44f& camera)
	{
		if (m_ringBufferData == nullptr)
			return;
		if (instanceParameter.InstanceCount < 2)
			return;

		bool isFirst = instanceParameter.InstanceIndex == 0;
		bool isLast = instanceParameter.InstanceIndex == (instanceParameter.InstanceCount - 1);

		auto& param = instanceParameter;

		if (isFirst)
		{
			instances.reserve(param.InstanceCount);
			instances.resize(0);
			innstancesNodeParam = parameter;
		}

		instances.push_back(param);

		if (isLast)
		{
			RenderSplines<VERTEX, FLIP_RGB>(camera);
		}
	}

public:
	void BeginRenderingGroup(const efkRibbonNodeParam& param, int32_t count, void* userData) override
	{
		m_ribbonCount = 0;
		int32_t vertexCount = ((count - 1) * param.SplineDivision) * 4;
		if (vertexCount <= 0)
			return;

		EffekseerRenderer::StandardRendererState state;
		state.AlphaBlend = param.BasicParameterPtr->AlphaBlend;
		state.CullingType = ::Effekseer::CullingType::Double;
		state.DepthTest = param.ZTest;
		state.DepthWrite = param.ZWrite;
		/*
		state.TextureFilter1 = param.BasicParameterPtr->TextureFilter1;
		state.TextureWrap1 = param.BasicParameterPtr->TextureWrap1;
		state.TextureFilter2 = param.BasicParameterPtr->TextureFilter2;
		state.TextureWrap2 = param.BasicParameterPtr->TextureWrap2;
		state.TextureFilter3 = param.BasicParameterPtr->TextureFilter3;
		state.TextureWrap3 = param.BasicParameterPtr->TextureWrap3;
		state.TextureFilter4 = param.BasicParameterPtr->TextureFilter4;
		state.TextureWrap4 = param.BasicParameterPtr->TextureWrap4;
		state.TextureFilter5 = param.BasicParameterPtr->TextureFilter5;
		state.TextureWrap5 = param.BasicParameterPtr->TextureWrap5;
		state.TextureFilter6 = param.BasicParameterPtr->TextureFilter6;
		state.TextureWrap6 = param.BasicParameterPtr->TextureWrap6;
		state.TextureFilter7 = param.BasicParameterPtr->TextureFilter7;
		state.TextureWrap7 = param.BasicParameterPtr->TextureWrap7;
		*/

		state.EnableInterpolation = param.BasicParameterPtr->EnableInterpolation;
		state.UVLoopType = param.BasicParameterPtr->UVLoopType;
		state.InterpolationType = param.BasicParameterPtr->InterpolationType;
		state.FlipbookDivideX = param.BasicParameterPtr->FlipbookDivideX;
		state.FlipbookDivideY = param.BasicParameterPtr->FlipbookDivideY;

		state.UVDistortionIntensity = param.BasicParameterPtr->UVDistortionIntensity;

		state.TextureBlendType = param.BasicParameterPtr->TextureBlendType;

		state.BlendUVDistortionIntensity = param.BasicParameterPtr->BlendUVDistortionIntensity;

		state.EmissiveScaling = param.BasicParameterPtr->EmissiveScaling;

		state.EdgeThreshold = param.BasicParameterPtr->EdgeThreshold;
		state.EdgeColor[0] = param.BasicParameterPtr->EdgeColor[0];
		state.EdgeColor[1] = param.BasicParameterPtr->EdgeColor[1];
		state.EdgeColor[2] = param.BasicParameterPtr->EdgeColor[2];
		state.EdgeColor[3] = param.BasicParameterPtr->EdgeColor[3];
		state.EdgeColorScaling = param.BasicParameterPtr->EdgeColorScaling;
		state.IsAlphaCuttoffEnabled = param.BasicParameterPtr->IsAlphaCutoffEnabled;
		state.Maginification = param.Maginification;

		state.Distortion = param.BasicParameterPtr->MaterialType == Effekseer::RendererMaterialType::BackDistortion;
		state.DistortionIntensity = param.BasicParameterPtr->DistortionIntensity;
		state.MaterialType = param.BasicParameterPtr->MaterialType;

		state.RenderingUserData = param.UserData;
		state.HandleUserData = userData;

		state.CopyMaterialFromParameterToState(
			m_renderer,
			param.EffectPointer,
			param.BasicParameterPtr);

		customData1Count_ = state.CustomData1Count;
		customData2Count_ = state.CustomData2Count;

		m_renderer->GetStandardRenderer()->UpdateStateAndRenderingIfRequired(state);

		m_renderer->GetStandardRenderer()->BeginRenderingAndRenderingIfRequired(vertexCount, stride_, (void*&)m_ringBufferData);
		vertexCount_ = vertexCount;
	}

	void Rendering(const efkRibbonNodeParam& parameter, const efkRibbonInstanceParam& instanceParameter, void* userData) override
	{
		Rendering_(parameter, instanceParameter, m_renderer->GetCameraMatrix());
	}
};
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace EffekseerRenderer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#endif // __EFFEKSEERRENDERER_RIBBON_RENDERER_H__