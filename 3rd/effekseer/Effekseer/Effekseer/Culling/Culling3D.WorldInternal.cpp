
#include "Culling3D.WorldInternal.h"
#include "Culling3D.ObjectInternal.h"

#include <complex>
#include <cstring>
#include <fstream>
#include <limits>

namespace Culling3D
{
const int32_t viewCullingXDiv = 2;
const int32_t viewCullingYDiv = 2;
const int32_t viewCullingZDiv = 3;

bool IsInView(Vector3DF position, float radius, Vector3DF facePositions[6], Vector3DF faceDir[6])
{
	for (int32_t i = 0; i < 6; i++)
	{
		Vector3DF diff = position - facePositions[i];
		float distance = Vector3DF::Dot(diff, faceDir[i]);

		if (distance > radius)
			return false;
	}

	return true;
}

World* World::Create(float xSize, float ySize, float zSize, int32_t layerCount)
{
	return new WorldInternal(xSize, ySize, zSize, layerCount);
}

WorldInternal::WorldInternal(float xSize, float ySize, float zSize, int32_t layerCount)
{
	this->xSize = xSize;
	this->ySize = ySize;
	this->zSize = zSize;

	this->gridSize = Max(Max(this->xSize, this->ySize), this->zSize);

	this->layerCount = layerCount;

	layers.resize(this->layerCount);

	for (size_t i = 0; i < layers.size(); i++)
	{
		float gridSize_ = this->gridSize / powf(2.0f, (float)i);

		int32_t xCount = (int32_t)(this->xSize / gridSize_);
		int32_t yCount = (int32_t)(this->ySize / gridSize_);
		int32_t zCount = (int32_t)(this->zSize / gridSize_);

		if (xCount * gridSize_ < this->xSize)
			xCount++;
		if (yCount * gridSize_ < this->ySize)
			yCount++;
		if (zCount * gridSize_ < this->zSize)
			zCount++;

		layers[i] = new Layer(xCount, yCount, zCount, xSize / 2.0f, ySize / 2.0f, zSize / 2.0f, gridSize_);

		this->minGridSize = gridSize_;
	}
}

WorldInternal::~WorldInternal()
{
	for (size_t i = 0; i < layers.size(); i++)
	{
		delete layers[i];
	}

	layers.clear();

	for (std::set<Object*>::iterator it = containedObjects.begin(); it != containedObjects.end(); it++)
	{
		(*it)->Release();
	}
}

void WorldInternal::AddObject(Object* o)
{
	SafeAddRef(o);
	containedObjects.insert(o);
	AddObjectInternal(o);
}

void WorldInternal::RemoveObject(Object* o)
{
	RemoveObjectInternal(o);
	containedObjects.erase(o);
	SafeRelease(o);
}

void WorldInternal::AddObjectInternal(Object* o)
{
	assert(o != nullptr);

	ObjectInternal* o_ = (ObjectInternal*)o;

	if (o_->GetNextStatus().Type == OBJECT_SHAPE_TYPE_ALL)
	{
		allLayers.AddObject(o);
		o_->SetWorld(this);
		return;
	}

	float radius = o_->GetNextStatus().GetRadius();
	if (o_->GetNextStatus().Type == OBJECT_SHAPE_TYPE_NONE || radius <= minGridSize)
	{
		if (layers[layers.size() - 1]->AddObject(o))
		{
		}
		else
		{
			outofLayers.AddObject(o);
		}
		o_->SetWorld(this);
		return;
	}

	int32_t gridInd = (int32_t)(gridSize / (radius * 2.0f));

	if (gridInd * (radius * 2) < gridSize)
		gridInd++;

	int32_t ind = 1;
	bool found = false;
	for (size_t i = 0; i < layers.size(); i++)
	{
		if (ind <= gridInd && gridInd < ind * 2)
		{
			if (layers[i]->AddObject(o))
			{
				((ObjectInternal*)o)->SetWorld(this);
				found = true;
			}
			else
			{
				break;
			}
		}

		ind *= 2;
	}

	if (!found)
	{
		((ObjectInternal*)o)->SetWorld(this);
		outofLayers.AddObject(o);
	}
}

void WorldInternal::RemoveObjectInternal(Object* o)
{
	assert(o != nullptr);

	ObjectInternal* o_ = (ObjectInternal*)o;

	if (o_->GetCurrentStatus().Type == OBJECT_SHAPE_TYPE_ALL)
	{
		allLayers.RemoveObject(o);
		o_->SetWorld(nullptr);
		return;
	}

	float radius = o_->GetCurrentStatus().GetRadius();
	if (o_->GetCurrentStatus().Type == OBJECT_SHAPE_TYPE_NONE || radius <= minGridSize)
	{
		if (layers[layers.size() - 1]->RemoveObject(o))
		{
		}
		else
		{
			outofLayers.RemoveObject(o);
		}
		o_->SetWorld(nullptr);
		return;
	}

	int32_t gridInd = (int32_t)(gridSize / (radius * 2.0f));

	if (gridInd * (radius * 2.0f) < gridSize)
		gridInd++;

	int32_t ind = 1;
	bool found = false;
	for (size_t i = 0; i < layers.size(); i++)
	{
		if (ind <= gridInd && gridInd < ind * 2)
		{
			if (layers[i]->RemoveObject(o))
			{
				((ObjectInternal*)o)->SetWorld(nullptr);
				found = true;
			}
			else
			{
				break;
			}
		}

		ind *= 2;
	}

	if (!found)
	{
		((ObjectInternal*)o)->SetWorld(nullptr);
		outofLayers.RemoveObject(o);
	}
}

void WorldInternal::CastRay(Vector3DF from, Vector3DF to)
{
	objs.clear();

	Vector3DF aabb_max;
	Vector3DF aabb_min;

	aabb_max.X = Max(from.X, to.X);
	aabb_max.Y = Max(from.Y, to.Y);
	aabb_max.Z = Max(from.Z, to.Z);

	aabb_min.X = Min(from.X, to.X);
	aabb_min.Y = Min(from.Y, to.Y);
	aabb_min.Z = Min(from.Z, to.Z);

	/* 範囲内に含まれるグリッドを取得 */
	for (size_t i = 0; i < layers.size(); i++)
	{
		layers[i]->AddGrids(aabb_max, aabb_min, grids);
	}

	/* 外領域追加 */
	grids.push_back(&outofLayers);
	grids.push_back(&allLayers);

	/* グリッドからオブジェクト取得 */

	/* 初期計算 */
	auto ray_dir = (to - from);
	auto ray_len = ray_dir.GetLength();
	ray_dir.Normalize();

	for (size_t i = 0; i < grids.size(); i++)
	{
		for (size_t j = 0; j < grids[i]->GetObjects().size(); j++)
		{
			Object* o = grids[i]->GetObjects()[j];
			ObjectInternal* o_ = (ObjectInternal*)o;

			if (o_->GetNextStatus().Type == OBJECT_SHAPE_TYPE_ALL)
			{
				objs.push_back(o);
				continue;
			}

			// 球線分判定
			{
				auto radius = o_->GetNextStatus().GetRadius();
				auto pos = o_->GetNextStatus().Position;

				auto from2pos = pos - from;
				auto from2nearLen = Vector3DF::Dot(from2pos, ray_dir);
				auto pos2ray = from2pos - ray_dir * from2nearLen;

				if (pos2ray.GetLength() > radius)
					continue;
				if (from2nearLen < 0 || from2nearLen > ray_len)
					continue;
			}

			if (o_->GetNextStatus().Type == OBJECT_SHAPE_TYPE_SPHERE)
			{
				objs.push_back(o);
				continue;
			}

			// AABB判定
			// 参考：http://marupeke296.com/COL_3D_No18_LineAndAABB.html

			if (o_->GetNextStatus().Type == OBJECT_SHAPE_TYPE_CUBOID)
			{
				// 交差判定
				float p[3], d[3], min[3], max[3];
				auto pos = o_->GetCurrentStatus().Position;
				memcpy(p, &from, sizeof(Vector3DF));
				memcpy(d, &ray_dir, sizeof(Vector3DF));
				memcpy(min, &pos, sizeof(Vector3DF));
				memcpy(max, &pos, sizeof(Vector3DF));

				min[0] -= o_->GetNextStatus().Data.Cuboid.X / 2.0f;
				min[1] -= o_->GetNextStatus().Data.Cuboid.Y / 2.0f;
				min[2] -= o_->GetNextStatus().Data.Cuboid.Z / 2.0f;

				max[0] += o_->GetNextStatus().Data.Cuboid.X / 2.0f;
				max[1] += o_->GetNextStatus().Data.Cuboid.Y / 2.0f;
				max[2] += o_->GetNextStatus().Data.Cuboid.Z / 2.0f;

				float t = -FLT_MAX;
				float t_max = FLT_MAX;

				for (int k = 0; k < 3; ++k)
				{
					if (std::abs(d[k]) < FLT_EPSILON)
					{
						if (p[k] < min[k] || p[k] > max[k])
						{
							// 交差していない
							continue;
						}
					}
					else
					{
						// スラブとの距離を算出
						// t1が近スラブ、t2が遠スラブとの距離
						float odd = 1.0f / d[k];
						float t1 = (min[k] - p[k]) * odd;
						float t2 = (max[k] - p[k]) * odd;
						if (t1 > t2)
						{
							float tmp = t1;
							t1 = t2;
							t2 = tmp;
						}

						if (t1 > t)
							t = t1;
						if (t2 < t_max)
							t_max = t2;

						// スラブ交差チェック
						if (t >= t_max)
						{
							// 交差していない
							continue;
						}
					}
				}

				// 交差している
				if (0 <= t && t <= ray_len)
				{
					objs.push_back(o);
					continue;
				}
			}
		}
	}

	/* 取得したグリッドを破棄 */
	for (size_t i = 0; i < grids.size(); i++)
	{
		grids[i]->IsScanned = false;
	}

	grids.clear();
}

void WorldInternal::Culling(const Matrix44& cameraProjMat, bool isOpenGL)
{
	objs.clear();

	if (!std::isinf(cameraProjMat.Values[2][2]) && cameraProjMat.Values[0][0] != 0.0f && cameraProjMat.Values[1][1] != 0.0f)
	{

		Matrix44 cameraProjMatInv = cameraProjMat;
		cameraProjMatInv.SetInverted();

		float maxx = 1.0f;
		float minx = -1.0f;

		float maxy = 1.0f;
		float miny = -1.0f;

		float maxz = 1.0f;
		float minz = 0.0f;
		if (isOpenGL)
			minz = -1.0f;

		Vector3DF eyebox[8];

		eyebox[0 + 0] = Vector3DF(minx, miny, maxz);
		eyebox[1 + 0] = Vector3DF(maxx, miny, maxz);
		eyebox[2 + 0] = Vector3DF(minx, maxy, maxz);
		eyebox[3 + 0] = Vector3DF(maxx, maxy, maxz);

		eyebox[0 + 4] = Vector3DF(minx, miny, minz);
		eyebox[1 + 4] = Vector3DF(maxx, miny, minz);
		eyebox[2 + 4] = Vector3DF(minx, maxy, minz);
		eyebox[3 + 4] = Vector3DF(maxx, maxy, minz);

		for (int32_t i = 0; i < 8; i++)
		{
			eyebox[i] = cameraProjMatInv.Transform3D(eyebox[i]);
		}

		// 0-right 1-left 2-top 3-bottom 4-front 5-back
		Vector3DF facePositions[6];
		facePositions[0] = eyebox[5];
		facePositions[1] = eyebox[4];
		facePositions[2] = eyebox[6];
		facePositions[3] = eyebox[4];
		facePositions[4] = eyebox[4];
		facePositions[5] = eyebox[0];

		Vector3DF faceDir[6];
		faceDir[0] = Vector3DF::Cross(eyebox[1] - eyebox[5], eyebox[7] - eyebox[5]);
		faceDir[1] = Vector3DF::Cross(eyebox[6] - eyebox[4], eyebox[0] - eyebox[4]);

		faceDir[2] = Vector3DF::Cross(eyebox[7] - eyebox[6], eyebox[2] - eyebox[6]);
		faceDir[3] = Vector3DF::Cross(eyebox[0] - eyebox[4], eyebox[5] - eyebox[4]);

		faceDir[4] = Vector3DF::Cross(eyebox[5] - eyebox[4], eyebox[6] - eyebox[4]);
		faceDir[5] = Vector3DF::Cross(eyebox[2] - eyebox[0], eyebox[1] - eyebox[5]);

		for (int32_t i = 0; i < 6; i++)
		{
			faceDir[i].Normalize();
		}

		for (int32_t z = 0; z < viewCullingZDiv; z++)
		{
			for (int32_t y = 0; y < viewCullingYDiv; y++)
			{
				for (int32_t x = 0; x < viewCullingXDiv; x++)
				{
					Vector3DF eyebox_[8];

					float xsize = 1.0f / (float)viewCullingXDiv;
					float ysize = 1.0f / (float)viewCullingYDiv;
					float zsize = 1.0f / (float)viewCullingZDiv;

					for (int32_t e = 0; e < 8; e++)
					{
						float x_ = 0.0f, y_ = 0.0f, z_ = 0.0f;
						if (e == 0)
						{
							x_ = xsize * x;
							y_ = ysize * y;
							z_ = zsize * z;
						}
						if (e == 1)
						{
							x_ = xsize * (x + 1);
							y_ = ysize * y;
							z_ = zsize * z;
						}
						if (e == 2)
						{
							x_ = xsize * x;
							y_ = ysize * (y + 1);
							z_ = zsize * z;
						}
						if (e == 3)
						{
							x_ = xsize * (x + 1);
							y_ = ysize * (y + 1);
							z_ = zsize * z;
						}
						if (e == 4)
						{
							x_ = xsize * x;
							y_ = ysize * y;
							z_ = zsize * (z + 1);
						}
						if (e == 5)
						{
							x_ = xsize * (x + 1);
							y_ = ysize * y;
							z_ = zsize * (z + 1);
						}
						if (e == 6)
						{
							x_ = xsize * x;
							y_ = ysize * (y + 1);
							z_ = zsize * (z + 1);
						}
						if (e == 7)
						{
							x_ = xsize * (x + 1);
							y_ = ysize * (y + 1);
							z_ = zsize * (z + 1);
						}

						Vector3DF yzMid[4];
						yzMid[0] = eyebox[0] * x_ + eyebox[1] * (1.0f - x_);
						yzMid[1] = eyebox[2] * x_ + eyebox[3] * (1.0f - x_);
						yzMid[2] = eyebox[4] * x_ + eyebox[5] * (1.0f - x_);
						yzMid[3] = eyebox[6] * x_ + eyebox[7] * (1.0f - x_);

						Vector3DF zMid[2];
						zMid[0] = yzMid[0] * y_ + yzMid[1] * (1.0f - y_);
						zMid[1] = yzMid[2] * y_ + yzMid[3] * (1.0f - y_);

						eyebox_[e] = zMid[0] * z_ + zMid[1] * (1.0f - z_);
					}

					Vector3DF max_(-FLT_MAX, -FLT_MAX, -FLT_MAX);
					Vector3DF min_(FLT_MAX, FLT_MAX, FLT_MAX);

					for (int32_t i = 0; i < 8; i++)
					{
						if (eyebox_[i].X > max_.X)
							max_.X = eyebox_[i].X;
						if (eyebox_[i].Y > max_.Y)
							max_.Y = eyebox_[i].Y;
						if (eyebox_[i].Z > max_.Z)
							max_.Z = eyebox_[i].Z;

						if (eyebox_[i].X < min_.X)
							min_.X = eyebox_[i].X;
						if (eyebox_[i].Y < min_.Y)
							min_.Y = eyebox_[i].Y;
						if (eyebox_[i].Z < min_.Z)
							min_.Z = eyebox_[i].Z;
					}

					/* 範囲内に含まれるグリッドを取得 */
					for (size_t i = 0; i < layers.size(); i++)
					{
						layers[i]->AddGrids(max_, min_, grids);
					}
				}
			}
		}

		/* 外領域追加 */
		grids.push_back(&outofLayers);
		grids.push_back(&allLayers);

		/* グリッドからオブジェクト取得 */
		for (size_t i = 0; i < grids.size(); i++)
		{
			for (size_t j = 0; j < grids[i]->GetObjects().size(); j++)
			{
				Object* o = grids[i]->GetObjects()[j];
				ObjectInternal* o_ = (ObjectInternal*)o;

				if (o_->GetNextStatus().Type == OBJECT_SHAPE_TYPE_ALL ||
					IsInView(o_->GetPosition(), o_->GetNextStatus().GetRadius(), facePositions, faceDir))
				{
					objs.push_back(o);
				}
			}
		}

		/* 取得したグリッドを破棄 */
		for (size_t i = 0; i < grids.size(); i++)
		{
			grids[i]->IsScanned = false;
		}

		grids.clear();
	}
	else
	{
		grids.push_back(&allLayers);

		/* グリッドからオブジェクト取得 */
		for (size_t i = 0; i < grids.size(); i++)
		{
			for (size_t j = 0; j < grids[i]->GetObjects().size(); j++)
			{
				Object* o = grids[i]->GetObjects()[j];
				ObjectInternal* o_ = (ObjectInternal*)o;

				if (o_->GetNextStatus().Type == OBJECT_SHAPE_TYPE_ALL)
				{
					objs.push_back(o);
				}
			}
		}

		/* 取得したグリッドを破棄 */
		for (size_t i = 0; i < grids.size(); i++)
		{
			grids[i]->IsScanned = false;
		}

		grids.clear();
	}
}

bool WorldInternal::Reassign()
{
	/* 数が少ない */
	if (outofLayers.GetObjects().size() < 10)
		return false;

	objs.clear();

	for (size_t i = 0; i < layers.size(); i++)
	{
		delete layers[i];
	}

	layers.clear();
	outofLayers.GetObjects().clear();
	allLayers.GetObjects().clear();

	outofLayers.IsScanned = false;
	allLayers.IsScanned = false;

	for (auto& it : containedObjects)
	{
		auto o = (ObjectInternal*)(it);
		o->ObjectIndex = -1;
	}

	float xmin = FLT_MAX;
	float xmax = -FLT_MAX;
	float ymin = FLT_MAX;
	float ymax = -FLT_MAX;
	float zmin = FLT_MAX;
	float zmax = -FLT_MAX;

	for (auto& it : containedObjects)
	{
		ObjectInternal* o_ = (ObjectInternal*)it;
		if (o_->GetNextStatus().Type == OBJECT_SHAPE_TYPE_ALL)
			continue;

		if (xmin > o_->GetNextStatus().Position.X)
			xmin = o_->GetNextStatus().Position.X;
		if (xmax < o_->GetNextStatus().Position.X)
			xmax = o_->GetNextStatus().Position.X;
		if (ymin > o_->GetNextStatus().Position.Y)
			ymin = o_->GetNextStatus().Position.Y;
		if (ymax < o_->GetNextStatus().Position.Y)
			ymax = o_->GetNextStatus().Position.Y;
		if (zmin > o_->GetNextStatus().Position.Z)
			zmin = o_->GetNextStatus().Position.Z;
		if (zmax < o_->GetNextStatus().Position.Z)
			zmax = o_->GetNextStatus().Position.Z;
	}

	auto xlen = Max(std::abs(xmax), std::abs(xmin)) * 2.0f;
	auto ylen = Max(std::abs(ymax), std::abs(ymin)) * 2.0f;
	auto zlen = Max(std::abs(zmax), std::abs(zmin)) * 2.0f;

	WorldInternal(xlen, ylen, zlen, this->layerCount);

	for (auto& it : containedObjects)
	{
		ObjectInternal* o_ = (ObjectInternal*)(it);
		AddObjectInternal(o_);
	}
	return true;
}

void WorldInternal::Dump(const char* path, const Matrix44& cameraProjMat, bool isOpenGL)
{
	std::ofstream ofs(path);

	/* カメラ情報出力 */
	Matrix44 cameraProjMatInv = cameraProjMat;
	cameraProjMatInv.SetInverted();

	float maxx = 1.0f;
	float minx = -1.0f;

	float maxy = 1.0f;
	float miny = -1.0f;

	float maxz = 1.0f;
	float minz = 0.0f;
	if (isOpenGL)
		minz = -1.0f;

	Vector3DF eyebox[8];

	eyebox[0 + 0] = Vector3DF(minx, miny, maxz);
	eyebox[1 + 0] = Vector3DF(maxx, miny, maxz);
	eyebox[2 + 0] = Vector3DF(minx, maxy, maxz);
	eyebox[3 + 0] = Vector3DF(maxx, maxy, maxz);

	eyebox[0 + 4] = Vector3DF(minx, miny, minz);
	eyebox[1 + 4] = Vector3DF(maxx, miny, minz);
	eyebox[2 + 4] = Vector3DF(minx, maxy, minz);
	eyebox[3 + 4] = Vector3DF(maxx, maxy, minz);

	for (int32_t i = 0; i < 8; i++)
	{
		eyebox[i] = cameraProjMatInv.Transform3D(eyebox[i]);
	}

	ofs << viewCullingXDiv << "," << viewCullingYDiv << "," << viewCullingZDiv << std::endl;
	for (int32_t i = 0; i < 8; i++)
	{
		ofs << eyebox[i].X << "," << eyebox[i].Y << "," << eyebox[i].Z << std::endl;
	}
	ofs << std::endl;

	for (int32_t z = 0; z < viewCullingZDiv; z++)
	{
		for (int32_t y = 0; y < viewCullingYDiv; y++)
		{
			for (int32_t x = 0; x < viewCullingXDiv; x++)
			{
				Vector3DF eyebox_[8];

				float xsize = 1.0f / (float)viewCullingXDiv;
				float ysize = 1.0f / (float)viewCullingYDiv;
				float zsize = 1.0f / (float)viewCullingZDiv;

				for (int32_t e = 0; e < 8; e++)
				{
					float x_ = 0.0f, y_ = 0.0f, z_ = 0.0f;
					if (e == 0)
					{
						x_ = xsize * x;
						y_ = ysize * y;
						z_ = zsize * z;
					}
					if (e == 1)
					{
						x_ = xsize * (x + 1);
						y_ = ysize * y;
						z_ = zsize * z;
					}
					if (e == 2)
					{
						x_ = xsize * x;
						y_ = ysize * (y + 1);
						z_ = zsize * z;
					}
					if (e == 3)
					{
						x_ = xsize * (x + 1);
						y_ = ysize * (y + 1);
						z_ = zsize * z;
					}
					if (e == 4)
					{
						x_ = xsize * x;
						y_ = ysize * y;
						z_ = zsize * (z + 1);
					}
					if (e == 5)
					{
						x_ = xsize * (x + 1);
						y_ = ysize * y;
						z_ = zsize * (z + 1);
					}
					if (e == 6)
					{
						x_ = xsize * x;
						y_ = ysize * (y + 1);
						z_ = zsize * (z + 1);
					}
					if (e == 7)
					{
						x_ = xsize * (x + 1);
						y_ = ysize * (y + 1);
						z_ = zsize * (z + 1);
					}

					Vector3DF yzMid[4];
					yzMid[0] = eyebox[0] * x_ + eyebox[1] * (1.0f - x_);
					yzMid[1] = eyebox[2] * x_ + eyebox[3] * (1.0f - x_);
					yzMid[2] = eyebox[4] * x_ + eyebox[5] * (1.0f - x_);
					yzMid[3] = eyebox[6] * x_ + eyebox[7] * (1.0f - x_);

					Vector3DF zMid[2];
					zMid[0] = yzMid[0] * y_ + yzMid[1] * (1.0f - y_);
					zMid[1] = yzMid[2] * y_ + yzMid[3] * (1.0f - y_);

					eyebox_[e] = zMid[0] * z_ + zMid[1] * (1.0f - z_);
				}

				Vector3DF max_(-FLT_MAX, -FLT_MAX, -FLT_MAX);
				Vector3DF min_(FLT_MAX, FLT_MAX, FLT_MAX);

				for (int32_t i = 0; i < 8; i++)
				{
					if (eyebox_[i].X > max_.X)
						max_.X = eyebox_[i].X;
					if (eyebox_[i].Y > max_.Y)
						max_.Y = eyebox_[i].Y;
					if (eyebox_[i].Z > max_.Z)
						max_.Z = eyebox_[i].Z;

					if (eyebox_[i].X < min_.X)
						min_.X = eyebox_[i].X;
					if (eyebox_[i].Y < min_.Y)
						min_.Y = eyebox_[i].Y;
					if (eyebox_[i].Z < min_.Z)
						min_.Z = eyebox_[i].Z;
				}

				ofs << x << "," << y << "," << z << std::endl;
				for (int32_t i = 0; i < 8; i++)
				{
					ofs << eyebox_[i].X << "," << eyebox_[i].Y << "," << eyebox_[i].Z << std::endl;
				}
				ofs << max_.X << "," << max_.Y << "," << max_.Z << std::endl;
				ofs << min_.X << "," << min_.Y << "," << min_.Z << std::endl;
				ofs << std::endl;
			}
		}
	}

	ofs << std::endl;

	/* レイヤー情報 */
	ofs << layers.size() << std::endl;

	for (size_t i = 0; i < layers.size(); i++)
	{
		auto& layer = layers[i];
		ofs << layer->GetGridXCount() << "," << layer->GetGridYCount() << "," << layer->GetGridZCount() << "," << layer->GetOffsetX() << ","
			<< layer->GetOffsetY() << "," << layer->GetOffsetZ() << "," << layer->GetGridSize() << std::endl;

		for (size_t j = 0; j < layer->GetGrids().size(); j++)
		{
			auto& grid = layer->GetGrids()[j];

			if (grid.GetObjects().size() > 0)
			{
				ofs << j << "," << grid.GetObjects().size() << std::endl;
			}
		}
	}

	Culling(cameraProjMat, isOpenGL);
}
} // namespace Culling3D
