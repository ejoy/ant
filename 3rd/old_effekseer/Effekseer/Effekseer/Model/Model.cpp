#include "Model.h"
#include "../Backend/GraphicsDevice.h"

namespace Effekseer
{

Model::Model(const CustomVector<Vertex>& vertecies, const CustomVector<Face>& faces)
{
	models_.resize(1);
	models_[0].vertexes = vertecies;
	models_[0].faces = faces;
}

Model::Model(const void* data, int32_t size)
{
	const uint8_t* p = (const uint8_t*)data;

	memcpy(&version_, p, sizeof(int32_t));
	p += sizeof(int32_t);

	// load scale except version 3(for compatibility)
	if (version_ == 2 || version_ >= 5)
	{
		// Scale
		p += sizeof(int32_t);
	}

	// For compatibility
	int32_t modelCount = 0;
	memcpy(&modelCount, p, sizeof(int32_t));
	p += sizeof(int32_t);

	int32_t frameCount = 1;

	if (version_ >= 5)
	{
		memcpy(&frameCount, p, sizeof(int32_t));
		p += sizeof(int32_t);
	}

	models_.resize(frameCount);

	for (int32_t f = 0; f < frameCount; f++)
	{
		int32_t vertexCount = 0;
		memcpy(&vertexCount, p, sizeof(int32_t));
		p += sizeof(int32_t);

		models_[f].vertexes.resize(vertexCount);

		if (version_ >= 1)
		{
			memcpy(models_[f].vertexes.data(), p, sizeof(Vertex) * vertexCount);
			p += sizeof(Vertex) * vertexCount;
		}
		else
		{
			for (int32_t i = 0; i < vertexCount; i++)
			{
				memcpy((void*)&models_[f].vertexes[i], p, sizeof(Vertex) - sizeof(Color));
				models_[f].vertexes[i].VColor = Color(255, 255, 255, 255);
				p += sizeof(Vertex) - sizeof(Color);
			}
		}

		int32_t faceCount = 0;
		memcpy(&faceCount, p, sizeof(int32_t));
		p += sizeof(int32_t);

		models_[f].faces.resize(faceCount);
		memcpy(models_[f].faces.data(), p, sizeof(Face) * faceCount);
		p += sizeof(Face) * faceCount;
	}
}

Model ::~Model()
{
}

const RefPtr<Backend::VertexBuffer>& Model::GetVertexBuffer(int32_t index) const
{
	return models_[index].vertexBuffer;
}

const RefPtr<Backend::IndexBuffer>& Model::GetIndexBuffer(int32_t index) const
{
	return models_[index].indexBuffer;
}

const RefPtr<Backend::IndexBuffer>& Model::GetWireIndexBuffer(int32_t index) const
{
	return models_[index].wireIndexBuffer;
}

const Model::Vertex* Model::GetVertexes(int32_t index) const
{
	return models_[index].vertexes.data();
}

int32_t Model::GetVertexCount(int32_t index) const
{
	return static_cast<int32_t>(models_[index].vertexes.size());
}

const Model::Face* Model::GetFaces(int32_t index) const
{
	return models_[index].faces.data();
}

int32_t Model::GetFaceCount(int32_t index) const
{
	return static_cast<int32_t>(models_[index].faces.size());
}

int32_t Model::GetFrameCount() const
{
	return static_cast<int32_t>(models_.size());
}

Model::Emitter Model::GetEmitter(IRandObject* g, int32_t time, CoordinateSystem coordinate, float magnification)
{
	time = time % GetFrameCount();

	const auto faceCount = GetFaceCount(time);
	if (faceCount == 0)
	{
		return GetEmitterFromVertex(g, time, coordinate, magnification);
	}

	int32_t faceInd = (int32_t)((GetFaceCount(time) - 1) * (g->GetRand()));
	faceInd = Clamp(faceInd, GetFaceCount(time) - 1, 0);
	const Face& face = GetFaces(time)[faceInd];
	const Vertex& v0 = GetVertexes(time)[face.Indexes[0]];
	const Vertex& v1 = GetVertexes(time)[face.Indexes[1]];
	const Vertex& v2 = GetVertexes(time)[face.Indexes[2]];

	float p1 = g->GetRand();
	float p2 = g->GetRand();

	// Fit within plane
	if (p1 + p2 > 1.0f)
	{
		p1 = 1.0f - p1;
		p2 = 1.0f - p2;
	}

	float p0 = 1.0f - p1 - p2;

	Emitter emitter;
	emitter.Position = (v0.Position * p0 + v1.Position * p1 + v2.Position * p2) * magnification;
	emitter.Normal = v0.Normal * p0 + v1.Normal * p1 + v2.Normal * p2;
	emitter.Binormal = v0.Binormal * p0 + v1.Binormal * p1 + v2.Binormal * p2;
	emitter.Tangent = v0.Tangent * p0 + v1.Tangent * p1 + v2.Tangent * p2;

	if (coordinate == CoordinateSystem::LH)
	{
		emitter.Position.Z = -emitter.Position.Z;
		emitter.Normal.Z = -emitter.Normal.Z;
		emitter.Binormal.Z = -emitter.Binormal.Z;
		emitter.Tangent.Z = -emitter.Tangent.Z;
	}

	return emitter;
}

Model::Emitter Model::GetEmitterFromVertex(IRandObject* g, int32_t time, CoordinateSystem coordinate, float magnification)
{
	time = time % GetFrameCount();

	const auto vertexCount = GetVertexCount(time);
	if (vertexCount == 0)
	{
		return Model::Emitter{};
	}

	int32_t vertexInd = (int32_t)((GetVertexCount(time) - 1) * (g->GetRand()));
	vertexInd = Clamp(vertexInd, GetVertexCount(time) - 1, 0);
	const Vertex& v = GetVertexes(time)[vertexInd];

	Emitter emitter;
	emitter.Position = v.Position * magnification;
	emitter.Normal = v.Normal;
	emitter.Binormal = v.Binormal;
	emitter.Tangent = v.Tangent;

	if (coordinate == CoordinateSystem::LH)
	{
		emitter.Position.Z = -emitter.Position.Z;
		emitter.Normal.Z = -emitter.Normal.Z;
		emitter.Binormal.Z = -emitter.Binormal.Z;
		emitter.Tangent.Z = -emitter.Tangent.Z;
	}

	return emitter;
}

Model::Emitter Model::GetEmitterFromVertex(int32_t index, int32_t time, CoordinateSystem coordinate, float magnification)
{
	time = time % GetFrameCount();

	const auto vertexCount = GetVertexCount(time);
	if (vertexCount == 0)
	{
		return Model::Emitter{};
	}

	int32_t vertexInd = index % GetVertexCount(time);
	const Vertex& v = GetVertexes(time)[vertexInd];

	Emitter emitter;
	emitter.Position = v.Position * magnification;
	emitter.Normal = v.Normal;
	emitter.Binormal = v.Binormal;
	emitter.Tangent = v.Tangent;

	if (coordinate == CoordinateSystem::LH)
	{
		emitter.Position.Z = -emitter.Position.Z;
		emitter.Normal.Z = -emitter.Normal.Z;
		emitter.Binormal.Z = -emitter.Binormal.Z;
		emitter.Tangent.Z = -emitter.Tangent.Z;
	}

	return emitter;
}

Model::Emitter Model::GetEmitterFromFace(IRandObject* g, int32_t time, CoordinateSystem coordinate, float magnification)
{
	time = time % GetFrameCount();

	const auto faceCount = GetFaceCount(time);
	if (faceCount == 0)
	{
		return Model::Emitter{};
	}

	int32_t faceInd = (int32_t)((GetFaceCount(time) - 1) * (g->GetRand()));
	faceInd = Clamp(faceInd, GetFaceCount(time) - 1, 0);
	const Face& face = GetFaces(time)[faceInd];
	const Vertex& v0 = GetVertexes(time)[face.Indexes[0]];
	const Vertex& v1 = GetVertexes(time)[face.Indexes[1]];
	const Vertex& v2 = GetVertexes(time)[face.Indexes[2]];

	float p0 = 1.0f / 3.0f;
	float p1 = 1.0f / 3.0f;
	float p2 = 1.0f / 3.0f;

	Emitter emitter;
	emitter.Position = (v0.Position * p0 + v1.Position * p1 + v2.Position * p2) * magnification;
	emitter.Normal = v0.Normal * p0 + v1.Normal * p1 + v2.Normal * p2;
	emitter.Binormal = v0.Binormal * p0 + v1.Binormal * p1 + v2.Binormal * p2;
	emitter.Tangent = v0.Tangent * p0 + v1.Tangent * p1 + v2.Tangent * p2;

	if (coordinate == CoordinateSystem::LH)
	{
		emitter.Position.Z = -emitter.Position.Z;
		emitter.Normal.Z = -emitter.Normal.Z;
		emitter.Binormal.Z = -emitter.Binormal.Z;
		emitter.Tangent.Z = -emitter.Tangent.Z;
	}

	return emitter;
}

Model::Emitter Model::GetEmitterFromFace(int32_t index, int32_t time, CoordinateSystem coordinate, float magnification)
{
	time = time % GetFrameCount();

	const auto faceCount = GetFaceCount(time);
	if (faceCount == 0)
	{
		return Model::Emitter{};
	}

	int32_t faceInd = index % (GetFaceCount(time) - 1);
	const Face& face = GetFaces(time)[faceInd];
	const Vertex& v0 = GetVertexes(time)[face.Indexes[0]];
	const Vertex& v1 = GetVertexes(time)[face.Indexes[1]];
	const Vertex& v2 = GetVertexes(time)[face.Indexes[2]];

	float p0 = 1.0f / 3.0f;
	float p1 = 1.0f / 3.0f;
	float p2 = 1.0f / 3.0f;

	Emitter emitter;
	emitter.Position = (v0.Position * p0 + v1.Position * p1 + v2.Position * p2) * magnification;
	emitter.Normal = v0.Normal * p0 + v1.Normal * p1 + v2.Normal * p2;
	emitter.Binormal = v0.Binormal * p0 + v1.Binormal * p1 + v2.Binormal * p2;
	emitter.Tangent = v0.Tangent * p0 + v1.Tangent * p1 + v2.Tangent * p2;

	if (coordinate == CoordinateSystem::LH)
	{
		emitter.Position.Z = -emitter.Position.Z;
		emitter.Normal.Z = -emitter.Normal.Z;
		emitter.Binormal.Z = -emitter.Binormal.Z;
		emitter.Tangent.Z = -emitter.Tangent.Z;
	}

	return emitter;
}

bool Model::StoreBufferToGPU(Backend::GraphicsDevice* graphicsDevice)
{
	if (isBufferStoredOnGPU_)
	{
		return false;
	}

	if (graphicsDevice == nullptr)
	{
		return false;
	}

	for (int32_t f = 0; f < GetFrameCount(); f++)
	{
		{
			models_[f].vertexBuffer = graphicsDevice->CreateVertexBuffer(sizeof(Effekseer::Model::Vertex) * GetVertexCount(f), models_[f].vertexes.data(), false);
			if (models_[f].vertexBuffer == nullptr)
			{
				return false;
			}
		}

		{
			models_[f].indexBuffer = graphicsDevice->CreateIndexBuffer(3 * GetFaceCount(f), models_[f].faces.data(), Effekseer::Backend::IndexBufferStrideType::Stride4);
			if (models_[f].indexBuffer == nullptr)
			{
				return false;
			}
		}
	}

	isBufferStoredOnGPU_ = true;
	return true;
}

bool Model::GetIsBufferStoredOnGPU() const
{
	return isBufferStoredOnGPU_;
}

bool Model::GenerateWireIndexBuffer(Backend::GraphicsDevice* graphicsDevice)
{
	if (isWireIndexBufferGenerated_)
	{
		return true;
	}

	if (graphicsDevice == nullptr)
	{
		return false;
	}

	for (int32_t f = 0; f < GetFrameCount(); f++)
	{
		CustomVector<int32_t> indexes;
		indexes.reserve(GetFaceCount(f) * 6);

		auto fp = GetFaces(f);

		for (int32_t i = 0; i < GetFaceCount(f); i++)
		{
			indexes.emplace_back(fp->Indexes[0]);
			indexes.emplace_back(fp->Indexes[1]);
			indexes.emplace_back(fp->Indexes[1]);
			indexes.emplace_back(fp->Indexes[2]);
			indexes.emplace_back(fp->Indexes[2]);
			indexes.emplace_back(fp->Indexes[0]);
			fp++;
		}

		{
			models_[f].wireIndexBuffer = graphicsDevice->CreateIndexBuffer(indexes.size(), indexes.data(), Effekseer::Backend::IndexBufferStrideType::Stride4);
			if (models_[f].wireIndexBuffer == nullptr)
			{
				return false;
			}
		}
	}

	isWireIndexBufferGenerated_ = true;

	return isWireIndexBufferGenerated_;
}

bool Model::GetIsWireIndexBufferGenerated() const
{
	return isWireIndexBufferGenerated_;
}

} // namespace Effekseer