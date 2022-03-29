
#ifndef __EFFEKSEER_MODEL_H__
#define __EFFEKSEER_MODEL_H__

#include "../Effekseer.Base.h"
#include "../Effekseer.Color.h"
#include "../Effekseer.Manager.h"
#include "../Effekseer.Resource.h"
#include "../Effekseer.Vector2D.h"
#include "../Effekseer.Vector3D.h"
#include "../Utils/Effekseer.CustomAllocator.h"

namespace Effekseer
{

namespace Backend
{
class GraphicsDevice;
class VertexBuffer;
class IndexBuffer;
} // namespace Backend

/**
	@brief
	\~English	Model class
	\~Japanese	モデルクラス
*/
class Model : public Resource
{
public:
	static const int32_t Version = 1;

	struct Vertex
	{
		Vector3D Position;
		Vector3D Normal;
		Vector3D Binormal;
		Vector3D Tangent;
		Vector2D UV;
		Color VColor;
	};

	struct Face
	{
		std::array<int32_t, 3> Indexes;
	};

	struct Emitter
	{
		Vector3D Position;
		Vector3D Normal;
		Vector3D Binormal;
		Vector3D Tangent;
	};

protected:
	struct InternalModel
	{
		CustomVector<Vertex> vertexes;
		CustomVector<Face> faces;
		RefPtr<Backend::VertexBuffer> vertexBuffer;
		RefPtr<Backend::IndexBuffer> indexBuffer;
		RefPtr<Backend::IndexBuffer> wireIndexBuffer;
	};

	int32_t version_ = 0;
	CustomVector<InternalModel> models_;
	bool isBufferStoredOnGPU_ = false;
	bool isWireIndexBufferGenerated_ = false;

public:
	Model(const CustomVector<Vertex>& vertecies, const CustomVector<Face>& faces);

	Model(const void* data, int32_t size);

	virtual ~Model();

	const RefPtr<Backend::VertexBuffer>& GetVertexBuffer(int32_t index) const;

	const RefPtr<Backend::IndexBuffer>& GetIndexBuffer(int32_t index) const;

	const RefPtr<Backend::IndexBuffer>& GetWireIndexBuffer(int32_t index) const;

	const Vertex* GetVertexes(int32_t index = 0) const;

	int32_t GetVertexCount(int32_t index = 0) const;

	const Face* GetFaces(int32_t index = 0) const;

	int32_t GetFaceCount(int32_t index = 0) const;

	int32_t GetFrameCount() const;

	Emitter GetEmitter(IRandObject* g, int32_t time, CoordinateSystem coordinate, float magnification);

	Emitter GetEmitterFromVertex(IRandObject* g, int32_t time, CoordinateSystem coordinate, float magnification);

	Emitter GetEmitterFromVertex(int32_t index, int32_t time, CoordinateSystem coordinate, float magnification);

	Emitter GetEmitterFromFace(IRandObject* g, int32_t time, CoordinateSystem coordinate, float magnification);

	Emitter GetEmitterFromFace(int32_t index, int32_t time, CoordinateSystem coordinate, float magnification);

	bool StoreBufferToGPU(Backend::GraphicsDevice* graphicsDevice);

	bool GetIsBufferStoredOnGPU() const;

	bool GenerateWireIndexBuffer(Backend::GraphicsDevice* graphicsDevice);

	bool GetIsWireIndexBufferGenerated() const;
};

} // namespace Effekseer

#endif // __EFFEKSEER_MODEL_H__
