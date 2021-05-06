#include "Effekseer.Manager.h"
#include "Effekseer.ManagerImplemented.h"

#include "Effekseer.Effect.h"
#include "Effekseer.EffectImplemented.h"
#include "Effekseer.Resource.h"
#include "SIMD/Utils.h"

#include "Effekseer.EffectNode.h"
#include "Effekseer.Instance.h"
#include "Effekseer.InstanceChunk.h"
#include "Effekseer.InstanceContainer.h"
#include "Effekseer.InstanceGlobal.h"
#include "Effekseer.InstanceGroup.h"

#include "Effekseer.DefaultEffectLoader.h"
#include "Effekseer.MaterialLoader.h"
#include "Effekseer.TextureLoader.h"

#include "Effekseer.Setting.h"

#include "Renderer/Effekseer.ModelRenderer.h"
#include "Renderer/Effekseer.RibbonRenderer.h"
#include "Renderer/Effekseer.RingRenderer.h"
#include "Renderer/Effekseer.SpriteRenderer.h"
#include "Renderer/Effekseer.TrackRenderer.h"

#include "Effekseer.SoundLoader.h"
#include "Sound/Effekseer.SoundPlayer.h"

#include "Effekseer.CurveLoader.h"
#include "Model/ModelLoader.h"

#include <algorithm>
#include <iostream>

#include "Utils/Profiler.h"

namespace Effekseer
{

static int64_t GetTime(void)
{
	return std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now().time_since_epoch()).count();
}

//! TODO should be moved
static std::function<void(LogType, const std::string&)> g_logger;

void SetLogger(const std::function<void(LogType, const std::string&)>& logger)
{
	g_logger = logger;
}

void Log(LogType logType, const std::string& message)
{
	if (g_logger != nullptr)
	{
		g_logger(logType, message);
	}
}

Manager::DrawParameter::DrawParameter()
{
	CameraCullingMask = 1;
}

ManagerRef Manager::Create(int instance_max, bool autoFlip)
{
	return MakeRefPtr<ManagerImplemented>(instance_max, autoFlip);
}

SIMD::Mat43f* ManagerImplemented::DrawSet::GetEnabledGlobalMatrix()
{
	if (IsPreupdated)
	{
		InstanceContainer* pContainer = InstanceContainerPointer;
		if (pContainer == nullptr)
			return nullptr;

		auto firstGroup = pContainer->GetFirstGroup();
		if (firstGroup == nullptr)
			return nullptr;

		Instance* pInstance = pContainer->GetFirstGroup()->GetFirst();
		if (pInstance == nullptr)
			return nullptr;

		return &(pInstance->m_GlobalMatrix43);
	}
	else
	{
		return &(GlobalMatrix);
	}
}

void ManagerImplemented::DrawSet::CopyMatrixFromInstanceToRoot()
{
	if (IsPreupdated)
	{
		InstanceContainer* pContainer = InstanceContainerPointer;
		if (pContainer == nullptr)
			return;

		auto firstGroup = pContainer->GetFirstGroup();
		if (firstGroup == nullptr)
			return;

		Instance* pInstance = pContainer->GetFirstGroup()->GetFirst();
		if (pInstance == nullptr)
			return;

		GlobalMatrix = pInstance->m_GlobalMatrix43;
	}
}

Handle ManagerImplemented::AddDrawSet(const EffectRef& effect, InstanceContainer* pInstanceContainer, InstanceGlobal* pGlobalPointer)
{
	Handle Temp = m_NextHandle;

	// avoid an overflow
	if (m_NextHandle > std::numeric_limits<int32_t>::max() - 1)
	{
		m_NextHandle = 0;
	}
	m_NextHandle++;

	DrawSet drawset(effect, pInstanceContainer, pGlobalPointer);
	drawset.Self = Temp;

	m_DrawSets[Temp] = drawset;

	return Temp;
}

void ManagerImplemented::StopStoppingEffects()
{
	for (auto& draw_set_it : m_DrawSets)
	{
		DrawSet& draw_set = draw_set_it.second;
		if (draw_set.IsRemoving)
			continue;
		if (draw_set.GoingToStop)
			continue;

		bool isRemoving = false;

		// Empty
		if (!isRemoving && draw_set.GlobalPointer->GetInstanceCount() == 0)
		{
			isRemoving = true;
		}

		// Root only exists and none plan to create new instances
		if (!isRemoving && draw_set.GlobalPointer->GetInstanceCount() == 1)
		{
			InstanceContainer* pRootContainer = draw_set.InstanceContainerPointer;
			InstanceGroup* group = pRootContainer != nullptr ? pRootContainer->GetFirstGroup() : nullptr;

			if (group)
			{
				Instance* pRootInstance = group->GetFirst();

				if (pRootInstance && pRootInstance->GetState() == INSTANCE_STATE_ACTIVE && !pRootInstance->IsFirstTime())
				{
					bool canRemoved = true;
					for (int i = 0; i < pRootInstance->m_pEffectNode->GetChildrenCount(); i++)
					{
						if (pRootInstance->maxGenerationChildrenCount[i] > pRootInstance->m_generatedChildrenCount[i])
						{
							canRemoved = false;
							break;
						}
					}

					if (canRemoved)
					{
						// when a sound is not playing.
						if (m_soundPlayer == nullptr || !m_soundPlayer->CheckPlayingTag(draw_set.GlobalPointer))
						{
							isRemoving = true;
						}
					}
				}
			}
		}

		if (isRemoving)
		{
			StopEffect(draw_set_it.first);
		}
	}
}

void ManagerImplemented::GCDrawSet(bool isRemovingManager)
{
	// dispose instance groups
	{
		auto it = m_RemovingDrawSets[1].begin();
		while (it != m_RemovingDrawSets[1].end())
		{
			// HACK for UpdateHandle
			if (it->second.UpdateCountAfterRemoving < 2)
			{
				UpdateInstancesByInstanceGlobal(it->second);
				UpdateHandleInternal(it->second);
				it->second.UpdateCountAfterRemoving++;
			}

			DrawSet& drawset = (*it).second;

			// dispose all instances
			if (drawset.InstanceContainerPointer != nullptr)
			{
				drawset.InstanceContainerPointer->RemoveForcibly(true);
				ReleaseInstanceContainer(drawset.InstanceContainerPointer);
			}

			drawset.ParameterPointer = nullptr;
			ES_SAFE_DELETE(drawset.GlobalPointer);

			if (m_cullingWorld != nullptr && drawset.CullingObjectPointer != nullptr)
			{
				Culling3D::SafeRelease(drawset.CullingObjectPointer);
			}

			m_RemovingDrawSets[1].erase(it++);
		}
		m_RemovingDrawSets[1].clear();
	}

	// wait next frame to be removed
	{
		auto it = m_RemovingDrawSets[0].begin();
		while (it != m_RemovingDrawSets[0].end())
		{
			// HACK for UpdateHandle
			if (it->second.UpdateCountAfterRemoving < 1)
			{
				UpdateInstancesByInstanceGlobal(it->second);
				UpdateHandleInternal(it->second);
				it->second.UpdateCountAfterRemoving++;
			}

			m_RemovingDrawSets[1][(*it).first] = (*it).second;
			m_RemovingDrawSets[0].erase(it++);
		}
		m_RemovingDrawSets[0].clear();
	}

	{
		auto it = m_DrawSets.begin();
		while (it != m_DrawSets.end())
		{
			DrawSet& draw_set = (*it).second;

			if (draw_set.IsRemoving)
			{
				if ((*it).second.RemovingCallback != nullptr)
				{
					(*it).second.RemovingCallback(this, (*it).first, isRemovingManager);
				}

				if (m_cullingWorld != NULL && (*it).second.CullingObjectPointer != nullptr)
				{
					m_cullingWorld->RemoveObject((*it).second.CullingObjectPointer);
				}

				m_RemovingDrawSets[0][(*it).first] = (*it).second;
				m_DrawSets.erase(it++);
			}
			else
			{
				++it;
			}
		}
	}
}

InstanceContainer* ManagerImplemented::CreateInstanceContainer(
	EffectNode* pEffectNode, InstanceGlobal* pGlobal, bool isRoot, const SIMD::Mat43f& rootMatrix, Instance* pParent)
{
	if (pooledContainers_.empty())
	{
		return nullptr;
	}
	InstanceContainer* memory = pooledContainers_.front();
	pooledContainers_.pop();
	InstanceContainer* pContainer = new (memory) InstanceContainer(this, pEffectNode, pGlobal);

	for (int i = 0; i < pEffectNode->GetChildrenCount(); i++)
	{
		auto child = CreateInstanceContainer(pEffectNode->GetChild(i), pGlobal, false, Matrix43(), nullptr);
		if (child == nullptr)
		{
			ReleaseInstanceContainer(pContainer);
			return nullptr;
		}

		pContainer->AddChild(child);
	}

	if (isRoot)
	{
		auto group = pContainer->CreateInstanceGroup();
		if (group == nullptr)
		{
			ReleaseInstanceContainer(pContainer);
			return nullptr;
		}

		auto instance = group->CreateInstance();
		if (instance == nullptr)
		{
			group->IsReferencedFromInstance = false;
			pContainer->RemoveInvalidGroups();
			ReleaseInstanceContainer(pContainer);
			return nullptr;
		}

		pGlobal->SetRootContainer(pContainer);

		instance->Initialize(nullptr, 0, rootMatrix);

		// This group is not generated by an instance, so changed a flag
		group->IsReferencedFromInstance = false;
	}

	return pContainer;
}

void ManagerImplemented::ReleaseInstanceContainer(InstanceContainer* container)
{
	container->~InstanceContainer();
	pooledContainers_.push(container);
}

void* EFK_STDCALL ManagerImplemented::Malloc(unsigned int size)
{
	return (void*)new char*[size];
}

void EFK_STDCALL ManagerImplemented::Free(void* p, unsigned int size)
{
	char* pData = (char*)p;
	delete[] pData;
}

int EFK_STDCALL ManagerImplemented::Rand()
{
	return rand();
}

void ManagerImplemented::ExecuteEvents()
{
	for (auto& ds : m_DrawSets)
	{
		if (ds.second.GoingToStop)
		{
			InstanceContainer* pContainer = ds.second.InstanceContainerPointer;

			if (pContainer != nullptr)
			{
				pContainer->KillAllInstances(true);
			}

			ds.second.IsRemoving = true;
			if (GetSoundPlayer() != nullptr)
			{
				GetSoundPlayer()->StopTag(ds.second.GlobalPointer);
			}
		}

		if (ds.second.GoingToStopRoot)
		{
			InstanceContainer* pContainer = ds.second.InstanceContainerPointer;

			if (pContainer != nullptr)
			{
				pContainer->KillAllInstances(false);
			}
		}
	}
}

void ManagerImplemented::StoreSortingDrawSets(const Manager::DrawParameter& drawParameter)
{
	sortedRenderingDrawSets_.clear();

	if (m_culled)
	{
		for (size_t i = 0; i < m_culledObjects.size(); i++)
		{
			DrawSet& drawSet = *m_culledObjects[i];
			sortedRenderingDrawSets_.emplace_back(drawSet);
		}
	}
	else
	{
		for (const auto& ds : m_renderingDrawSets)
		{
			sortedRenderingDrawSets_.emplace_back(ds);
		}
	}

	if (drawParameter.IsSortingEffectsEnabled)
	{
		std::sort(sortedRenderingDrawSets_.begin(), sortedRenderingDrawSets_.end(), [&](const DrawSet& a, const DrawSet& b) -> bool {
			const auto da = SIMD::Vec3f::Dot(a.GlobalMatrix.GetTranslation() - drawParameter.CameraPosition, drawParameter.CameraFrontDirection);
			const auto db = SIMD::Vec3f::Dot(b.GlobalMatrix.GetTranslation() - drawParameter.CameraPosition, drawParameter.CameraFrontDirection);
			return da > db;
		});
	}
}

ManagerImplemented::ManagerImplemented(int instance_max, bool autoFlip)
	: m_autoFlip(autoFlip)
	, m_NextHandle(0)
	, m_instance_max(instance_max)
	, m_setting(nullptr)
	, m_sequenceNumber(0)

	, m_cullingWorld(nullptr)
	, m_culled(false)

	, m_spriteRenderer(nullptr)
	, m_ribbonRenderer(nullptr)
	, m_ringRenderer(nullptr)
	, m_modelRenderer(nullptr)
	, m_trackRenderer(nullptr)

	, m_soundPlayer(nullptr)

	, m_MallocFunc(nullptr)
	, m_FreeFunc(nullptr)
	, m_randFunc(nullptr)
	, m_randMax(0)
{
	m_setting = Setting::Create();

	SetMallocFunc(Malloc);
	SetFreeFunc(Free);
	SetRandFunc(Rand);
	SetRandMax(RAND_MAX);

	m_renderingDrawSets.reserve(64);

	int chunk_max = (m_instance_max + InstanceChunk::InstancesOfChunk - 1) / InstanceChunk::InstancesOfChunk;
	reservedChunksBuffer_.resize(chunk_max);
	for (auto& chunk : reservedChunksBuffer_)
	{
		pooledChunks_.push(&chunk);
	}
	for (auto& chunks : instanceChunks_)
	{
		chunks.reserve(chunk_max);
	}
	std::fill(creatableChunkOffsets_.begin(), creatableChunkOffsets_.end(), 0);

	// Pooling InstanceGroup
	reservedGroupBuffer_.resize(instance_max * sizeof(InstanceGroup));
	for (int i = 0; i < instance_max; i++)
	{
		pooledGroups_.push((InstanceGroup*)&reservedGroupBuffer_[i * sizeof(InstanceGroup)]);
	}

	// Pooling InstanceGroup
	reservedContainerBuffer_.resize(instance_max * sizeof(InstanceContainer));
	for (int i = 0; i < instance_max; i++)
	{
		pooledContainers_.push((InstanceContainer*)&reservedContainerBuffer_[i * sizeof(InstanceContainer)]);
	}

	m_setting->SetEffectLoader(Effect::CreateEffectLoader());
	EffekseerPrintDebug("*** Create : Manager\n");
}

ManagerImplemented::~ManagerImplemented()
{
	if (m_WorkerThreads.size() > 0)
	{
		m_WorkerThreads[0].WaitForComplete();
	}

	StopAllEffects();

	ExecuteEvents();

	for (int i = 0; i < 5; i++)
	{
		GCDrawSet(true);
	}

	// assert( m_reserved_instances.size() == m_instance_max );
	// ES_SAFE_DELETE_ARRAY( m_reserved_instances_buffer );

	Culling3D::SafeRelease(m_cullingWorld);
}

Instance* ManagerImplemented::CreateInstance(EffectNodeImplemented* pEffectNode, InstanceContainer* pContainer, InstanceGroup* pGroup)
{
	int32_t generationNumber = pEffectNode->GetGeneration();
	assert(generationNumber < GenerationsMax);

	auto& chunks = instanceChunks_[generationNumber];

	int32_t offset = creatableChunkOffsets_[generationNumber];

	auto it = std::find_if(chunks.begin() + offset, chunks.end(), [](const InstanceChunk* chunk) { return chunk->IsInstanceCreatable(); });

	creatableChunkOffsets_[generationNumber] = (int32_t)std::distance(chunks.begin(), it);

	if (it != chunks.end())
	{
		auto chunk = *it;
		return chunk->CreateInstance(this, pEffectNode, pContainer, pGroup);
	}

	if (!pooledChunks_.empty())
	{
		auto chunk = pooledChunks_.front();
		pooledChunks_.pop();
		chunks.push_back(chunk);
		return chunk->CreateInstance(this, pEffectNode, pContainer, pGroup);
	}

	return nullptr;
}

InstanceGroup* ManagerImplemented::CreateInstanceGroup(EffectNodeImplemented* pEffectNode, InstanceContainer* pContainer, InstanceGlobal* pGlobal)
{
	if (pooledGroups_.empty())
	{
		return nullptr;
	}
	InstanceGroup* memory = pooledGroups_.front();
	pooledGroups_.pop();
	return new (memory) InstanceGroup(this, pEffectNode, pContainer, pGlobal);
}

void ManagerImplemented::ReleaseGroup(InstanceGroup* group)
{
	group->~InstanceGroup();
	pooledGroups_.push(group);
}

void ManagerImplemented::LaunchWorkerThreads(uint32_t threadCount)
{
	m_WorkerThreads.resize(threadCount);

	for (auto& worker : m_WorkerThreads)
	{
		worker.Launch();
	}
}

ThreadNativeHandleType ManagerImplemented::GetWorkerThreadHandle(uint32_t threadID)
{
	if (threadID < m_WorkerThreads.size())
	{
		return m_WorkerThreads[threadID].GetThreadHandle();
	}
	return 0;
}

uint32_t ManagerImplemented::GetSequenceNumber() const
{
	return m_sequenceNumber;
}

MallocFunc ManagerImplemented::GetMallocFunc() const
{
	return m_MallocFunc;
}

void ManagerImplemented::SetMallocFunc(MallocFunc func)
{
	m_MallocFunc = func;
}

FreeFunc ManagerImplemented::GetFreeFunc() const
{
	return m_FreeFunc;
}

void ManagerImplemented::SetFreeFunc(FreeFunc func)
{
	m_FreeFunc = func;
}

RandFunc ManagerImplemented::GetRandFunc() const
{
	return m_randFunc;
}

void ManagerImplemented::SetRandFunc(RandFunc func)
{
	m_randFunc = func;
}

int ManagerImplemented::GetRandMax() const
{
	return m_randMax;
}

void ManagerImplemented::SetRandMax(int max_)
{
	m_randMax = max_;
}

CoordinateSystem ManagerImplemented::GetCoordinateSystem() const
{
	return m_setting->GetCoordinateSystem();
}

void ManagerImplemented::SetCoordinateSystem(CoordinateSystem coordinateSystem)
{
	m_setting->SetCoordinateSystem(coordinateSystem);
}

SpriteRendererRef ManagerImplemented::GetSpriteRenderer()
{
	return m_spriteRenderer;
}

void ManagerImplemented::SetSpriteRenderer(SpriteRendererRef renderer)
{
	m_spriteRenderer = renderer;
}

RibbonRendererRef ManagerImplemented::GetRibbonRenderer()
{
	return m_ribbonRenderer;
}

void ManagerImplemented::SetRibbonRenderer(RibbonRendererRef renderer)
{
	m_ribbonRenderer = renderer;
}

RingRendererRef ManagerImplemented::GetRingRenderer()
{
	return m_ringRenderer;
}

void ManagerImplemented::SetRingRenderer(RingRendererRef renderer)
{
	m_ringRenderer = renderer;
}

ModelRendererRef ManagerImplemented::GetModelRenderer()
{
	return m_modelRenderer;
}

void ManagerImplemented::SetModelRenderer(ModelRendererRef renderer)
{
	m_modelRenderer = renderer;
}

TrackRendererRef ManagerImplemented::GetTrackRenderer()
{
	return m_trackRenderer;
}

void ManagerImplemented::SetTrackRenderer(TrackRendererRef renderer)
{
	m_trackRenderer = renderer;
}

SoundPlayerRef ManagerImplemented::GetSoundPlayer()
{
	return m_soundPlayer;
}

void ManagerImplemented::SetSoundPlayer(SoundPlayerRef soundPlayer)
{
	m_soundPlayer = soundPlayer;
}

const SettingRef& ManagerImplemented::GetSetting() const
{
	return m_setting;
}

void ManagerImplemented::SetSetting(const SettingRef& setting)
{
	m_setting = setting;
}

EffectLoaderRef ManagerImplemented::GetEffectLoader()
{
	return m_setting->GetEffectLoader();
}

void ManagerImplemented::SetEffectLoader(EffectLoaderRef effectLoader)
{
	m_setting->SetEffectLoader(effectLoader);
}

TextureLoaderRef ManagerImplemented::GetTextureLoader()
{
	return m_setting->GetTextureLoader();
}

void ManagerImplemented::SetTextureLoader(TextureLoaderRef textureLoader)
{
	m_setting->SetTextureLoader(textureLoader);
}

SoundLoaderRef ManagerImplemented::GetSoundLoader()
{
	return m_setting->GetSoundLoader();
}

void ManagerImplemented::SetSoundLoader(SoundLoaderRef soundLoader)
{
	m_setting->SetSoundLoader(soundLoader);
}

ModelLoaderRef ManagerImplemented::GetModelLoader()
{
	return m_setting->GetModelLoader();
}

void ManagerImplemented::SetModelLoader(ModelLoaderRef modelLoader)
{
	m_setting->SetModelLoader(modelLoader);
}

MaterialLoaderRef ManagerImplemented::GetMaterialLoader()
{
	return m_setting->GetMaterialLoader();
}

void ManagerImplemented::SetMaterialLoader(MaterialLoaderRef loader)
{
	m_setting->SetMaterialLoader(loader);
}

CurveLoaderRef ManagerImplemented::GetCurveLoader()
{
	return m_setting->GetCurveLoader();
}

void ManagerImplemented::SetCurveLoader(CurveLoaderRef loader)
{
	m_setting->SetCurveLoader(loader);
}

void ManagerImplemented::StopEffect(Handle handle)
{
	if (m_DrawSets.count(handle) > 0)
	{
		DrawSet& drawSet = m_DrawSets[handle];
		drawSet.GoingToStop = true;
		drawSet.IsRemoving = true;
	}
}

void ManagerImplemented::StopAllEffects()
{
	for (auto& it : m_DrawSets)
	{
		it.second.GoingToStop = true;
		it.second.IsRemoving = true;
	}
}

void ManagerImplemented::StopRoot(Handle handle)
{
	if (m_DrawSets.count(handle) > 0)
	{
		m_DrawSets[handle].GoingToStopRoot = true;
	}
}

void ManagerImplemented::StopRoot(const EffectRef& effect)
{
	for (auto& it : m_DrawSets)
	{
		if (it.second.ParameterPointer == effect)
		{
			it.second.GoingToStopRoot = true;
		}
	}
}

bool ManagerImplemented::Exists(Handle handle)
{
	if (m_DrawSets.count(handle) > 0)
	{
		// always exists before update
		if (!m_DrawSets[handle].IsPreupdated)
			return true;

		if (m_DrawSets[handle].IsRemoving)
			return false;
		return true;
	}
	return false;
}

int32_t ManagerImplemented::GetInstanceCount(Handle handle)
{
	if (m_DrawSets.count(handle) > 0)
	{
		return m_DrawSets[handle].GlobalPointer->GetInstanceCount();
	}
	return 0;
}

int32_t ManagerImplemented::GetTotalInstanceCount() const
{
	int32_t instanceCount = 0;
	for (auto pair : m_DrawSets)
	{
		const DrawSet& drawSet = pair.second;
		instanceCount += drawSet.GlobalPointer->GetInstanceCount();
	}
	return instanceCount;
}

Matrix43 ManagerImplemented::GetMatrix(Handle handle)
{
	if (m_DrawSets.count(handle) > 0)
	{
		DrawSet& drawSet = m_DrawSets[handle];

		auto mat = drawSet.GetEnabledGlobalMatrix();

		if (mat != nullptr)
		{
			return ToStruct(*mat);
		}
	}

	return Matrix43();
}

void ManagerImplemented::SetMatrix(Handle handle, const Matrix43& mat)
{
	if (m_DrawSets.count(handle) > 0)
	{
		DrawSet& drawSet = m_DrawSets[handle];
		auto mat_ = drawSet.GetEnabledGlobalMatrix();

		if (mat_ != nullptr)
		{
			(*mat_) = mat;
			drawSet.CopyMatrixFromInstanceToRoot();
			drawSet.IsParameterChanged = true;
		}
	}
}

Vector3D ManagerImplemented::GetLocation(Handle handle)
{
	Vector3D location;

	if (m_DrawSets.count(handle) > 0)
	{
		DrawSet& drawSet = m_DrawSets[handle];
		auto mat_ = drawSet.GetEnabledGlobalMatrix();

		if (mat_ != nullptr)
		{
			location.X = mat_->X.GetW();
			location.Y = mat_->Y.GetW();
			location.Z = mat_->Z.GetW();
		}
	}

	return location;
}

void ManagerImplemented::SetLocation(Handle handle, float x, float y, float z)
{
	if (m_DrawSets.count(handle) > 0)
	{
		DrawSet& drawSet = m_DrawSets[handle];
		auto mat_ = drawSet.GetEnabledGlobalMatrix();

		if (mat_ != nullptr)
		{
			mat_->X.SetW(x);
			mat_->Y.SetW(y);
			mat_->Z.SetW(z);

			drawSet.CopyMatrixFromInstanceToRoot();
			drawSet.IsParameterChanged = true;
		}
	}
}

void ManagerImplemented::SetLocation(Handle handle, const Vector3D& location)
{
	SetLocation(handle, location.X, location.Y, location.Z);
}

void ManagerImplemented::AddLocation(Handle handle, const Vector3D& location)
{
	if (m_DrawSets.count(handle) > 0)
	{
		DrawSet& drawSet = m_DrawSets[handle];
		auto mat_ = drawSet.GetEnabledGlobalMatrix();

		if (mat_ != nullptr)
		{
			mat_->X.SetW(mat_->X.GetW() + location.X);
			mat_->Y.SetW(mat_->Y.GetW() + location.Y);
			mat_->Z.SetW(mat_->Z.GetW() + location.Z);
			drawSet.CopyMatrixFromInstanceToRoot();
			drawSet.IsParameterChanged = true;
		}
	}
}

void ManagerImplemented::SetRotation(Handle handle, float x, float y, float z)
{
	if (m_DrawSets.count(handle) > 0)
	{
		DrawSet& drawSet = m_DrawSets[handle];

		auto mat_ = drawSet.GetEnabledGlobalMatrix();

		if (mat_ != nullptr)
		{
			SIMD::Mat43f r;
			SIMD::Vec3f s, t;

			mat_->GetSRT(s, r, t);

			r = SIMD::Mat43f::RotationZXY(z, x, y);

			*mat_ = SIMD::Mat43f::SRT(s, r, t);

			drawSet.CopyMatrixFromInstanceToRoot();
			drawSet.IsParameterChanged = true;
		}
	}
}

void ManagerImplemented::SetRotation(Handle handle, const Vector3D& axis, float angle)
{
	if (m_DrawSets.count(handle) > 0)
	{
		DrawSet& drawSet = m_DrawSets[handle];

		auto mat_ = drawSet.GetEnabledGlobalMatrix();

		if (mat_ != nullptr)
		{
			SIMD::Mat43f r;
			SIMD::Vec3f s, t;

			mat_->GetSRT(s, r, t);

			r = SIMD::Mat43f::RotationAxis(axis, angle);

			*mat_ = SIMD::Mat43f::SRT(s, r, t);

			drawSet.CopyMatrixFromInstanceToRoot();
			drawSet.IsParameterChanged = true;
		}
	}
}

void ManagerImplemented::SetScale(Handle handle, float x, float y, float z)
{
	if (m_DrawSets.count(handle) > 0)
	{
		DrawSet& drawSet = m_DrawSets[handle];

		auto mat_ = drawSet.GetEnabledGlobalMatrix();

		if (mat_ != nullptr)
		{
			SIMD::Mat43f r;
			SIMD::Vec3f s, t;

			mat_->GetSRT(s, r, t);

			s = SIMD::Vec3f(x, y, z);

			*mat_ = SIMD::Mat43f::SRT(s, r, t);

			drawSet.CopyMatrixFromInstanceToRoot();
			drawSet.IsParameterChanged = true;
		}
	}
}

void ManagerImplemented::SetAllColor(Handle handle, Color color)
{
	if (m_DrawSets.count(handle) > 0)
	{
		auto& drawSet = m_DrawSets[handle];

		drawSet.GlobalPointer->IsGlobalColorSet = true;
		drawSet.GlobalPointer->GlobalColor = color;
	}
}

void ManagerImplemented::SetTargetLocation(Handle handle, float x, float y, float z)
{
	SetTargetLocation(handle, Vector3D(x, y, z));
}

void ManagerImplemented::SetTargetLocation(Handle handle, const Vector3D& location)
{
	if (m_DrawSets.count(handle) > 0)
	{
		DrawSet& drawSet = m_DrawSets[handle];

		InstanceGlobal* instanceGlobal = drawSet.GlobalPointer;
		instanceGlobal->SetTargetLocation(location);

		drawSet.IsParameterChanged = true;
	}
}

float ManagerImplemented::GetDynamicInput(Handle handle, int32_t index)
{
	auto it = m_DrawSets.find(handle);
	if (it != m_DrawSets.end())
	{
		auto globalPtr = it->second.GlobalPointer;
		if (index < 0 || globalPtr->dynamicInputParameters.size() <= index)
			return 0.0f;

		return globalPtr->dynamicInputParameters[index];
	}

	return 0.0f;
}

void ManagerImplemented::SetDynamicInput(Handle handle, int32_t index, float value)
{
	if (m_DrawSets.count(handle) > 0)
	{
		DrawSet& drawSet = m_DrawSets[handle];

		InstanceGlobal* instanceGlobal = drawSet.GlobalPointer;

		if (index < 0 || instanceGlobal->dynamicInputParameters.size() <= index)
			return;

		instanceGlobal->dynamicInputParameters[index] = value;

		drawSet.IsParameterChanged = true;
	}
}

Matrix43 ManagerImplemented::GetBaseMatrix(Handle handle)
{
	if (m_DrawSets.count(handle) > 0)
	{
		return ToStruct(m_DrawSets[handle].BaseMatrix);
	}

	return Matrix43();
}

void ManagerImplemented::SetBaseMatrix(Handle handle, const Matrix43& mat)
{
	if (m_DrawSets.count(handle) > 0)
	{
		m_DrawSets[handle].BaseMatrix = mat;
		m_DrawSets[handle].DoUseBaseMatrix = true;
		m_DrawSets[handle].IsParameterChanged = true;
	}
}

void ManagerImplemented::SetRemovingCallback(Handle handle, EffectInstanceRemovingCallback callback)
{
	if (m_DrawSets.count(handle) > 0)
	{
		m_DrawSets[handle].RemovingCallback = callback;
	}
}

bool ManagerImplemented::GetShown(Handle handle)
{
	if (m_DrawSets.count(handle) > 0)
	{
		return m_DrawSets[handle].IsShown;
	}

	return false;
}

void ManagerImplemented::SetShown(Handle handle, bool shown)
{
	if (m_DrawSets.count(handle) > 0)
	{
		m_DrawSets[handle].IsShown = shown;
	}
}

bool ManagerImplemented::GetPaused(Handle handle)
{
	if (m_DrawSets.count(handle) > 0)
	{
		return m_DrawSets[handle].IsPaused;
	}

	return false;
}

void ManagerImplemented::SetPaused(Handle handle, bool paused)
{
	if (m_DrawSets.count(handle) > 0)
	{
		m_DrawSets[handle].IsPaused = paused;
	}
}

void ManagerImplemented::SetPausedToAllEffects(bool paused)
{
	std::map<Handle, DrawSet>::iterator it = m_DrawSets.begin();
	while (it != m_DrawSets.end())
	{
		(*it).second.IsPaused = paused;
		++it;
	}
}

int ManagerImplemented::GetLayer(Handle handle)
{
	if (m_DrawSets.count(handle) > 0)
	{
		return m_DrawSets[handle].Layer;
	}
	return 0;
}

void ManagerImplemented::SetLayer(Handle handle, int32_t layer)
{
	if (m_DrawSets.count(handle) > 0)
	{
		m_DrawSets[handle].Layer = layer;
	}
}

int64_t ManagerImplemented::GetGroupMask(Handle handle) const
{
	auto it = m_DrawSets.find(handle);

	if (it != m_DrawSets.end())
	{
		return it->second.GroupMask;
	}

	return 0;
}

void ManagerImplemented::SetGroupMask(Handle handle, int64_t groupmask)
{
	auto it = m_DrawSets.find(handle);

	if (it != m_DrawSets.end())
	{
		it->second.GroupMask = groupmask;
	}
}

float ManagerImplemented::GetSpeed(Handle handle) const
{
	auto it = m_DrawSets.find(handle);
	if (it == m_DrawSets.end())
		return 0.0f;
	return it->second.Speed;
}

void ManagerImplemented::SetSpeed(Handle handle, float speed)
{
	if (m_DrawSets.count(handle) > 0)
	{
		m_DrawSets[handle].Speed = speed;
		m_DrawSets[handle].IsParameterChanged = true;
	}
}

void ManagerImplemented::SetTimeScaleByGroup(int64_t groupmask, float timeScale)
{
	for (auto& it : m_DrawSets)
	{
		if ((it.second.GroupMask & groupmask) != 0)
		{
			it.second.TimeScale = timeScale;
		}
	}
}

void ManagerImplemented::SetTimeScaleByHandle(Handle handle, float timeScale)
{
	auto it = m_DrawSets.find(handle);

	if (it != m_DrawSets.end())
	{
		it->second.TimeScale = timeScale;
	}
}

void ManagerImplemented::SetAutoDrawing(Handle handle, bool autoDraw)
{
	if (m_DrawSets.count(handle) > 0)
	{
		m_DrawSets[handle].IsAutoDrawing = autoDraw;
	}
}

void ManagerImplemented::SetUserData(Handle handle, void* userData)
{
	auto it = m_DrawSets.find(handle);

	if (it != m_DrawSets.end())
	{
		it->second.GlobalPointer->SetUserData(userData);
	}
}

void ManagerImplemented::Flip()
{
	PROFILER_BLOCK("Manager::Flip", profiler::colors::Red);

	if (!m_autoFlip)
	{
		m_renderingMutex.lock();
	}

	// execute preupdate
	for (auto& drawSet : m_DrawSets)
	{
		Preupdate(drawSet.second);
	}

	StopStoppingEffects();

	ExecuteEvents();

	GCDrawSet(false);

	m_renderingDrawSets.clear();
	m_renderingDrawSetMaps.clear();

	// Generate culling
	if (cullingNext.SizeX != cullingCurrent.SizeX || cullingNext.SizeY != cullingCurrent.SizeY ||
		cullingNext.SizeZ != cullingCurrent.SizeZ || cullingNext.LayerCount != cullingCurrent.LayerCount)
	{
		Culling3D::SafeRelease(m_cullingWorld);

		for (auto& it : m_DrawSets)
		{
			DrawSet& ds = it.second;
			Culling3D::SafeRelease(ds.CullingObjectPointer);
		}

		m_cullingWorld = Culling3D::World::Create(cullingNext.SizeX, cullingNext.SizeY, cullingNext.SizeZ, cullingNext.LayerCount);

		cullingCurrent = cullingNext;
	}

	{
		for (auto& it : m_DrawSets)
		{
			DrawSet& ds = it.second;
			EffectImplemented* effect = (EffectImplemented*)ds.ParameterPointer.Get();

			if (ds.InstanceContainerPointer == nullptr)
			{
				continue;
			}

			if (ds.IsParameterChanged)
			{
				if (m_cullingWorld != nullptr)
				{
					auto isCreated = false;

					if (ds.CullingObjectPointer == nullptr)
					{
						ds.CullingObjectPointer = Culling3D::Object::Create();
						if (effect->Culling.Shape == CullingShape::Sphere)
						{
							ds.CullingObjectPointer->ChangeIntoSphere(0.0f);
						}

						if (effect->Culling.Shape == CullingShape::NoneShape)
						{
							ds.CullingObjectPointer->ChangeIntoAll();
						}

						isCreated = true;
					}

					InstanceContainer* pContainer = ds.InstanceContainerPointer;
					Instance* pInstance = pContainer->GetFirstGroup()->GetFirst();

					Vector3D location;

					auto mat_ = ds.GetEnabledGlobalMatrix();

					if (mat_ != nullptr)
					{
						location.X = mat_->X.GetW();
						location.Y = mat_->Y.GetW();
						location.Z = mat_->Z.GetW();
					}

					ds.CullingObjectPointer->SetPosition(Culling3D::Vector3DF(location.X, location.Y, location.Z));

					if (effect->Culling.Shape == CullingShape::Sphere)
					{
						float radius = effect->Culling.Sphere.Radius;

						{
							SIMD::Vec3f s = pInstance->GetGlobalMatrix43().GetScale();
							radius *= s.GetLength();
							SIMD::Vec3f culling_pos = SIMD::Vec3f::Transform(SIMD::Vec3f(effect->Culling.Location), pInstance->GetGlobalMatrix43());
							ds.CullingObjectPointer->SetPosition(Culling3D::Vector3DF(culling_pos.GetX(), culling_pos.GetY(), culling_pos.GetZ()));
						}

						if (ds.DoUseBaseMatrix)
						{
							SIMD::Vec3f s = ds.BaseMatrix.GetScale();
							radius *= s.GetLength();
							SIMD::Vec3f culling_pos = SIMD::Vec3f::Transform(SIMD::Vec3f(effect->Culling.Location), ds.BaseMatrix);
							ds.CullingObjectPointer->SetPosition(Culling3D::Vector3DF(culling_pos.GetX(), culling_pos.GetY(), culling_pos.GetZ()));
						}

						ds.CullingObjectPointer->ChangeIntoSphere(radius);
					}

					if (isCreated)
					{
						m_cullingWorld->AddObject(ds.CullingObjectPointer);
					}
				}
				ds.IsParameterChanged = false;
			}

			m_renderingDrawSets.push_back(ds);
			m_renderingDrawSetMaps[it.first] = it.second;
		}

		if (m_cullingWorld != nullptr)
		{
			for (size_t i = 0; i < m_renderingDrawSets.size(); i++)
			{
				m_renderingDrawSets[i].CullingObjectPointer->SetUserData(&(m_renderingDrawSets[i]));
			}
		}
	}

	m_culledObjects.clear();
	m_culledObjectSets.clear();
	m_culled = false;

	if (!m_autoFlip)
	{
		m_renderingMutex.unlock();
	}
}

void ManagerImplemented::Update(float deltaFrame)
{
	UpdateParameter parameter;
	parameter.DeltaFrame = deltaFrame;
	parameter.UpdateInterval = 0.0f;
	Update(parameter);
}

void ManagerImplemented::Update(const UpdateParameter& parameter)
{
	PROFILER_BLOCK("Manager::Update", profiler::colors::Red);

	if (m_WorkerThreads.size() == 0)
	{
		DoUpdate(parameter);
	}
	else
	{
		m_WorkerThreads[0].WaitForComplete();
		// Process on worker thread
		m_WorkerThreads[0].RunAsync([this, parameter]() { DoUpdate(parameter); });

		if (parameter.SyncUpdate)
		{
			m_WorkerThreads[0].WaitForComplete();
		}
	}

	ExecuteSounds();
}

void ManagerImplemented::DoUpdate(const UpdateParameter& parameter)
{
	PROFILER_BLOCK("Manager::DoUpdate", profiler::colors::Red);
	// start to measure time
	int64_t beginTime = ::Effekseer::GetTime();

	// Hack for GC
	for (size_t i = 0; i < m_RemovingDrawSets.size(); i++)
	{
		for (auto& ds : m_RemovingDrawSets[i])
		{
			ds.second.UpdateCountAfterRemoving++;
		}
	}

	// add frames
	float maximumDeltaFrame = 0;

	for (auto& drawSet : m_DrawSets)
	{
		float df = drawSet.second.IsPaused ? 0 : parameter.DeltaFrame * drawSet.second.Speed * drawSet.second.TimeScale;
		drawSet.second.NextUpdateFrame += df;

		maximumDeltaFrame = std::max(maximumDeltaFrame, drawSet.second.NextUpdateFrame);
	}

	int times = 0;

	if (parameter.UpdateInterval != 0)
	{
		times = static_cast<int>(maximumDeltaFrame / parameter.UpdateInterval);
	}

	// Update once at least
	if (times == 0)
	{
		times = 1;
	}

	BeginUpdate();

	for (int32_t t = 0; t < times; t++)
	{
		// specify delta frames
		for (auto& drawSet : m_DrawSets)
		{
			if (drawSet.second.NextUpdateFrame >= parameter.UpdateInterval)
			{
				float idf = 0;

				if (parameter.UpdateInterval > 0)
				{
					idf = parameter.UpdateInterval;
				}
				else
				{
					idf = drawSet.second.NextUpdateFrame;
				}

				drawSet.second.NextUpdateFrame -= idf;
				drawSet.second.GlobalPointer->BeginDeltaFrame(idf);
			}
			else
			{
				drawSet.second.GlobalPointer->BeginDeltaFrame(0);
			}
		}

		for (auto& chunks : instanceChunks_)
		{
			if (m_WorkerThreads.size() >= 2)
			{
				const uint32_t chunkStep = (uint32_t)m_WorkerThreads.size();

				for (uint32_t threadID = 1; threadID < (uint32_t)m_WorkerThreads.size(); threadID++)
				{
					const uint32_t chunkOffset = threadID;
					// Process on worker thread
					m_WorkerThreads[threadID].RunAsync([this, &chunks, chunkOffset, chunkStep]() {
						PROFILER_BLOCK("DoUpdate::RunAsync", profiler::colors::Red);
						for (size_t i = chunkOffset; i < chunks.size(); i += chunkStep)
						{
							chunks[i]->UpdateInstances();
						}
					});
				}

				// Process on this thread
				for (size_t i = 0; i < chunks.size(); i += chunkStep)
				{
					chunks[i]->UpdateInstances();
				}

				// Wait for all worker threads completion
				for (uint32_t threadID = 1; threadID < (uint32_t)m_WorkerThreads.size(); threadID++)
				{
					m_WorkerThreads[threadID].WaitForComplete();
				}
			}
			else
			{
				for (auto chunk : chunks)
				{
					chunk->UpdateInstances();
				}
			}

			for (auto chunk : chunks)
			{
				chunk->GenerateChildrenInRequired();
			}
		}

		for (auto& drawSet : m_DrawSets)
		{
			UpdateHandleInternal(drawSet.second);
		}
	}

	EndUpdate();

	// end to measure time
	m_updateTime = (int)(Effekseer::GetTime() - beginTime);
}

void ManagerImplemented::BeginUpdate()
{
	m_renderingMutex.lock();
	m_isLockedWithRenderingMutex = true;

	if (m_autoFlip)
	{
		Flip();
	}

	m_sequenceNumber++;
}

void ManagerImplemented::EndUpdate()
{
	for (auto& chunks : instanceChunks_)
	{
		auto first = chunks.begin();
		auto last = chunks.end();
		while (first != last)
		{
			auto it = std::find_if(first, last, [](const InstanceChunk* chunk) { return chunk->GetAliveCount() == 0; });
			if (it != last)
			{
				pooledChunks_.push(*it);
				if (it != last - 1)
					*it = *(last - 1);
				last--;
			}
			first = it;
		}
		chunks.erase(last, chunks.end());
	}
	std::fill(creatableChunkOffsets_.begin(), creatableChunkOffsets_.end(), 0);

	m_renderingMutex.unlock();
	m_isLockedWithRenderingMutex = false;
}

void ManagerImplemented::UpdateHandle(Handle handle, float deltaFrame)
{
	{
		auto it = m_DrawSets.find(handle);
		if (it != m_DrawSets.end())
		{
			DrawSet& drawSet = it->second;

			{
				float df = drawSet.IsPaused ? 0 : deltaFrame * drawSet.Speed * drawSet.TimeScale;
				drawSet.NextUpdateFrame += df;

				drawSet.GlobalPointer->BeginDeltaFrame(drawSet.NextUpdateFrame);
				drawSet.NextUpdateFrame = 0.0f;
			}

			UpdateInstancesByInstanceGlobal(drawSet);

			UpdateHandleInternal(drawSet);
		}
	}

	ExecuteSounds();
}

void ManagerImplemented::UpdateHandleToMoveToFrame(Handle handle, float frame)
{
	auto it = m_DrawSets.find(handle);
	if (it == m_DrawSets.end())
	{
		return;
	}

	DrawSet& drawSet = it->second;

	if (frame < drawSet.GlobalPointer->GetUpdatedFrame())
	{
		StopWithoutRemoveDrawSet(drawSet);
		ResetAndPlayWithDataSet(drawSet, frame);
	}
	else
	{
		auto updatedFrame = drawSet.GlobalPointer->GetUpdatedFrame();
		for (int i = 0; i < frame - updatedFrame; i++)
		{
			UpdateHandle(handle, 1);
		}
	}
}

void ManagerImplemented::UpdateInstancesByInstanceGlobal(const DrawSet& drawSet)
{
	for (auto& chunks : instanceChunks_)
	{
		for (auto chunk : chunks)
		{
			chunk->UpdateInstancesByInstanceGlobal(drawSet.GlobalPointer);
		}

		for (auto chunk : chunks)
		{
			chunk->GenerateChildrenInRequiredByInstanceGlobal(drawSet.GlobalPointer);
		}
	}
}

void ManagerImplemented::UpdateHandleInternal(DrawSet& drawSet)
{
	// calculate dynamic parameters
	auto e = static_cast<EffectImplemented*>(drawSet.ParameterPointer.Get());
	assert(e != nullptr);
	assert(drawSet.GlobalPointer->dynamicEqResults.size() >= e->dynamicEquation.size());

	std::array<float, 1> globals;
	globals[0] = drawSet.GlobalPointer->GetUpdatedFrame() / 60.0f;

	for (size_t i = 0; i < e->dynamicEquation.size(); i++)
	{
		if (e->dynamicEquation[i].GetRunningPhase() != InternalScript::RunningPhaseType::Global)
			continue;

		drawSet.GlobalPointer->dynamicEqResults[i] = e->dynamicEquation[i].Execute(drawSet.GlobalPointer->dynamicInputParameters,
																				   globals,
																				   std::array<float, 5>(),
																				   RandCallback::Rand,
																				   RandCallback::RandSeed,
																				   drawSet.GlobalPointer);
	}

	Preupdate(drawSet);

	if (drawSet.InstanceContainerPointer != nullptr)
	{
		drawSet.InstanceContainerPointer->Update(true, drawSet.IsShown);

		if (drawSet.DoUseBaseMatrix)
		{
			drawSet.InstanceContainerPointer->SetBaseMatrix(true, drawSet.BaseMatrix);
		}
	}

	drawSet.GlobalPointer->EndDeltaFrame();
}

void ManagerImplemented::Preupdate(DrawSet& drawSet)
{
	if (drawSet.IsPreupdated)
		return;

	// Create an instance through a container
	InstanceContainer* pContainer =
		CreateInstanceContainer(drawSet.ParameterPointer->GetRoot(), drawSet.GlobalPointer, true, drawSet.GlobalMatrix, nullptr);

	drawSet.InstanceContainerPointer = pContainer;
	drawSet.IsPreupdated = true;

	if (drawSet.InstanceContainerPointer == nullptr)
	{
		drawSet.IsRemoving = true;
		return;
	}

	drawSet.InstanceContainerPointer->GetFirstGroup()->GetFirst()->FirstUpdate();

	for (int32_t frame = 0; frame < drawSet.StartFrame; frame++)
	{
		drawSet.GlobalPointer->BeginDeltaFrame(1.0f);

		UpdateInstancesByInstanceGlobal(drawSet);

		UpdateHandleInternal(drawSet);
	}
}

bool ManagerImplemented::IsClippedWithDepth(DrawSet& drawSet, InstanceContainer* container, const Manager::DrawParameter& drawParameter)
{

	// don't use this parameter
	if (container->m_pEffectNode->DepthValues.DepthParameter.DepthClipping > FLT_MAX / 10)
		return false;

	SIMD::Vec3f pos = drawSet.GlobalMatrix.GetTranslation();
	auto distance = SIMD::Vec3f::Dot(pos - SIMD::Vec3f(drawParameter.CameraPosition), SIMD::Vec3f(drawParameter.CameraFrontDirection));
	if (container->m_pEffectNode->DepthValues.DepthParameter.DepthClipping < distance)
	{
		return true;
	}
	else
	{
		return false;
	}
}

void ManagerImplemented::StopWithoutRemoveDrawSet(DrawSet& drawSet)
{
	drawSet.InstanceContainerPointer->KillAllInstances(true);
	drawSet.InstanceContainerPointer->RemoveForcibly(true);
	ReleaseInstanceContainer(drawSet.InstanceContainerPointer);
	drawSet.InstanceContainerPointer = nullptr;
	ES_SAFE_RELEASE(drawSet.CullingObjectPointer);
}

void ManagerImplemented::ResetAndPlayWithDataSet(DrawSet& drawSet, float frame)
{
	assert(drawSet.ParameterPointer != nullptr);
	auto effect = drawSet.ParameterPointer->GetRoot();
	assert(effect != nullptr);

	auto pGlobal = drawSet.GlobalPointer;
	auto e = static_cast<EffectImplemented*>(drawSet.ParameterPointer.Get());

	// reallocate
	pGlobal->GetRandObject().SetSeed(drawSet.RandomSeed);

	pGlobal->RenderedInstanceContainers.resize(e->renderingNodesCount);
	for (size_t i = 0; i < pGlobal->RenderedInstanceContainers.size(); i++)
	{
		pGlobal->RenderedInstanceContainers[i] = nullptr;
	}

	drawSet.IsPreupdated = false;
	drawSet.IsParameterChanged = true;
	drawSet.StartFrame = 0;
	drawSet.GoingToStop = false;
	drawSet.GoingToStopRoot = false;
	drawSet.IsRemoving = false;
	pGlobal->ResetUpdatedFrame();

	// Create an instance through a container
	//drawSet.InstanceContainerPointer = CreateInstanceContainer(e->GetRoot(), drawSet.GlobalPointer, true, drawSet.GlobalMatrix, nullptr);

	auto isShown = drawSet.IsShown;
	drawSet.IsShown = false;

	// skip
	Preupdate(drawSet);

	for (float f = 0; f < frame - 1; f += 1.0f)
	{
		drawSet.GlobalPointer->BeginDeltaFrame(1.0f);

		UpdateInstancesByInstanceGlobal(drawSet);
		UpdateHandleInternal(drawSet);
		//drawSet.InstanceContainerPointer->Update(true, false);
		drawSet.GlobalPointer->EndDeltaFrame();
	}

	drawSet.IsShown = isShown;

	drawSet.GlobalPointer->BeginDeltaFrame(1.0f);

	UpdateInstancesByInstanceGlobal(drawSet);
	UpdateHandleInternal(drawSet);

	//drawSet.InstanceContainerPointer->Update(true, drawSet.IsShown);
	drawSet.GlobalPointer->EndDeltaFrame();
}

void ManagerImplemented::Draw(const Manager::DrawParameter& drawParameter)
{
	PROFILER_BLOCK("Manager::Draw", profiler::colors::Blue);

	if (m_WorkerThreads.size() > 0)
	{
		m_WorkerThreads[0].WaitForComplete();
	}

	std::lock_guard<std::mutex> lock(m_renderingMutex);

	// start to record a time
	int64_t beginTime = ::Effekseer::GetTime();

	const auto render = [this, &drawParameter](DrawSet& drawSet) -> void {
		if (drawSet.InstanceContainerPointer == nullptr)
		{
			return;
		}

		if (drawSet.IsShown && drawSet.IsAutoDrawing && ((drawParameter.CameraCullingMask & (1 << drawSet.Layer)) != 0))
		{
			if (drawSet.GlobalPointer->RenderedInstanceContainers.size() > 0)
			{
				for (auto& c : drawSet.GlobalPointer->RenderedInstanceContainers)
				{
					if (IsClippedWithDepth(drawSet, c, drawParameter))
						continue;

					c->Draw(false);
				}
			}
			else
			{
				drawSet.InstanceContainerPointer->Draw(true);
			}
		}
	};

	if (drawParameter.IsSortingEffectsEnabled)
	{
		StoreSortingDrawSets(drawParameter);

		for (auto& drawSet : sortedRenderingDrawSets_)
		{
			render(drawSet);
		}
	}
	else
	{
		if (m_culled)
		{
			for (size_t i = 0; i < m_culledObjects.size(); i++)
			{
				render(*m_culledObjects[i]);
			}
		}
		else
		{
			for (size_t i = 0; i < m_renderingDrawSets.size(); i++)
			{
				render(m_renderingDrawSets[i]);
			}
		}
	}

	// calculate a time
	m_drawTime = (int)(Effekseer::GetTime() - beginTime);
}

void ManagerImplemented::DrawBack(const Manager::DrawParameter& drawParameter)
{
	std::lock_guard<std::mutex> lock(m_renderingMutex);

	// start to record a time
	int64_t beginTime = ::Effekseer::GetTime();

	const auto render = [this, &drawParameter](DrawSet& drawSet) -> void {
		if (drawSet.InstanceContainerPointer == nullptr)
		{
			return;
		}

		if (drawSet.IsShown && drawSet.IsAutoDrawing && ((drawParameter.CameraCullingMask & (1 << drawSet.Layer)) != 0))
		{
			auto e = (EffectImplemented*)drawSet.ParameterPointer.Get();
			for (int32_t j = 0; j < e->renderingNodesThreshold; j++)
			{
				if (IsClippedWithDepth(drawSet, drawSet.GlobalPointer->RenderedInstanceContainers[j], drawParameter))
					continue;

				drawSet.GlobalPointer->RenderedInstanceContainers[j]->Draw(false);
			}
		}
	};

	if (drawParameter.IsSortingEffectsEnabled)
	{
		StoreSortingDrawSets(drawParameter);

		for (auto& drawSet : sortedRenderingDrawSets_)
		{
			render(drawSet);
		}
	}
	else
	{
		if (m_culled)
		{
			for (size_t i = 0; i < m_culledObjects.size(); i++)
			{
				render(*m_culledObjects[i]);
			}
		}
		else
		{
			for (size_t i = 0; i < m_renderingDrawSets.size(); i++)
			{
				render(m_renderingDrawSets[i]);
			}
		}
	}

	// calculate a time
	m_drawTime = (int)(Effekseer::GetTime() - beginTime);
}

void ManagerImplemented::DrawFront(const Manager::DrawParameter& drawParameter)
{
	std::lock_guard<std::mutex> lock(m_renderingMutex);

	// start to record a time
	int64_t beginTime = ::Effekseer::GetTime();

	const auto render = [this, &drawParameter](DrawSet& drawSet) -> void {
		if (drawSet.InstanceContainerPointer == nullptr)
		{
			return;
		}

		if (drawSet.IsShown && drawSet.IsAutoDrawing && ((drawParameter.CameraCullingMask & (1 << drawSet.Layer)) != 0))
		{
			if (drawSet.GlobalPointer->RenderedInstanceContainers.size() > 0)
			{
				auto e = (EffectImplemented*)drawSet.ParameterPointer.Get();
				for (size_t j = e->renderingNodesThreshold; j < drawSet.GlobalPointer->RenderedInstanceContainers.size(); j++)
				{
					if (IsClippedWithDepth(drawSet, drawSet.GlobalPointer->RenderedInstanceContainers[j], drawParameter))
						continue;

					drawSet.GlobalPointer->RenderedInstanceContainers[j]->Draw(false);
				}
			}
			else
			{
				drawSet.InstanceContainerPointer->Draw(true);
			}
		}
	};

	if (drawParameter.IsSortingEffectsEnabled)
	{
		StoreSortingDrawSets(drawParameter);

		for (auto& drawSet : sortedRenderingDrawSets_)
		{
			render(drawSet);
		}
	}
	else
	{
		if (m_culled)
		{
			for (size_t i = 0; i < m_culledObjects.size(); i++)
			{
				render(*m_culledObjects[i]);
			}
		}
		else
		{
			for (size_t i = 0; i < m_renderingDrawSets.size(); i++)
			{
				render(m_renderingDrawSets[i]);
			}
		}
	}

	// calculate a time
	m_drawTime = (int)(Effekseer::GetTime() - beginTime);
}

Handle ManagerImplemented::Play(const EffectRef& effect, float x, float y, float z)
{
	return Play(effect, Vector3D(x, y, z), 0);
}

Handle ManagerImplemented::Play(const EffectRef& effect, const Vector3D& position, int32_t startFrame)
{
	if (effect == nullptr)
		return -1;

	auto e = effect->GetImplemented();

	// Create root
	InstanceGlobal* pGlobal = new InstanceGlobal();

	int32_t randomSeed = 0;
	if (e->m_defaultRandomSeed >= 0)
	{
		randomSeed = e->m_defaultRandomSeed;
	}
	else
	{
		randomSeed = GetRandFunc()();
	}

	pGlobal->GetRandObject().SetSeed(randomSeed);

	pGlobal->dynamicInputParameters = e->defaultDynamicInputs;

	pGlobal->RenderedInstanceContainers.resize(e->renderingNodesCount);
	for (size_t i = 0; i < pGlobal->RenderedInstanceContainers.size(); i++)
	{
		pGlobal->RenderedInstanceContainers[i] = nullptr;
	}

	// create a dateSet without an instance
	// an instance is created in Preupdate because effects need to show instances without update(0 frame)
	Handle handle = AddDrawSet(effect, nullptr, pGlobal);

	auto& drawSet = m_DrawSets[handle];

	drawSet.GlobalMatrix = SIMD::Mat43f::Translation(position);

	drawSet.IsParameterChanged = true;
	drawSet.StartFrame = startFrame;
	drawSet.RandomSeed = randomSeed;

	return handle;
}

int ManagerImplemented::GetCameraCullingMaskToShowAllEffects()
{
	int mask = 0;

	for (auto& ds : m_DrawSets)
	{
		auto layer = 1 << ds.second.Layer;
		mask |= layer;
	}

	return mask;
}

void ManagerImplemented::DrawHandle(Handle handle, const Manager::DrawParameter& drawParameter)
{
	if (m_WorkerThreads.size() > 0)
	{
		m_WorkerThreads[0].WaitForComplete();
	}

	std::lock_guard<std::mutex> lock(m_renderingMutex);

	auto it = m_renderingDrawSetMaps.find(handle);
	if (it != m_renderingDrawSetMaps.end())
	{
		DrawSet& drawSet = it->second;

		if (drawSet.InstanceContainerPointer == nullptr)
		{
			return;
		}

		if (m_culled)
		{
			if (m_culledObjectSets.find(drawSet.Self) != m_culledObjectSets.end())
			{
				if (drawSet.IsShown)
				{
					if (drawSet.GlobalPointer->RenderedInstanceContainers.size() > 0)
					{
						for (auto& c : drawSet.GlobalPointer->RenderedInstanceContainers)
						{
							if (IsClippedWithDepth(drawSet, c, drawParameter))
								continue;

							c->Draw(false);
						}
					}
					else
					{
						drawSet.InstanceContainerPointer->Draw(true);
					}
				}
			}
		}
		else
		{
			if (drawSet.IsShown)
			{
				if (drawSet.GlobalPointer->RenderedInstanceContainers.size() > 0)
				{
					for (auto& c : drawSet.GlobalPointer->RenderedInstanceContainers)
					{
						if (IsClippedWithDepth(drawSet, c, drawParameter))
							continue;

						c->Draw(false);
					}
				}
				else
				{
					drawSet.InstanceContainerPointer->Draw(true);
				}
			}
		}
	}
}

void ManagerImplemented::DrawHandleBack(Handle handle, const Manager::DrawParameter& drawParameter)
{
	if (m_WorkerThreads.size() > 0)
	{
		m_WorkerThreads[0].WaitForComplete();
	}

	std::lock_guard<std::mutex> lock(m_renderingMutex);

	std::map<Handle, DrawSet>::iterator it = m_renderingDrawSetMaps.find(handle);
	if (it != m_renderingDrawSetMaps.end())
	{
		DrawSet& drawSet = it->second;
		auto e = (EffectImplemented*)drawSet.ParameterPointer.Get();

		if (m_culled)
		{
			if (m_culledObjectSets.find(drawSet.Self) != m_culledObjectSets.end())
			{
				if (drawSet.IsShown)
				{
					for (int32_t i = 0; i < e->renderingNodesThreshold; i++)
					{
						if (IsClippedWithDepth(drawSet, drawSet.GlobalPointer->RenderedInstanceContainers[i], drawParameter))
							continue;

						drawSet.GlobalPointer->RenderedInstanceContainers[i]->Draw(false);
					}
				}
			}
		}
		else
		{
			if (drawSet.IsShown)
			{
				for (int32_t i = 0; i < e->renderingNodesThreshold; i++)
				{
					if (IsClippedWithDepth(drawSet, drawSet.GlobalPointer->RenderedInstanceContainers[i], drawParameter))
						continue;

					drawSet.GlobalPointer->RenderedInstanceContainers[i]->Draw(false);
				}
			}
		}
	}
}

void ManagerImplemented::DrawHandleFront(Handle handle, const Manager::DrawParameter& drawParameter)
{
	if (m_WorkerThreads.size() > 0)
	{
		m_WorkerThreads[0].WaitForComplete();
	}

	std::lock_guard<std::mutex> lock(m_renderingMutex);

	std::map<Handle, DrawSet>::iterator it = m_renderingDrawSetMaps.find(handle);
	if (it != m_renderingDrawSetMaps.end())
	{
		DrawSet& drawSet = it->second;
		auto e = (EffectImplemented*)drawSet.ParameterPointer.Get();

		if (drawSet.InstanceContainerPointer == nullptr)
		{
			return;
		}

		if (m_culled)
		{
			if (m_culledObjectSets.find(drawSet.Self) != m_culledObjectSets.end())
			{
				if (drawSet.IsShown)
				{
					if (drawSet.GlobalPointer->RenderedInstanceContainers.size() > 0)
					{
						for (size_t i = e->renderingNodesThreshold; i < drawSet.GlobalPointer->RenderedInstanceContainers.size(); i++)
						{
							if (IsClippedWithDepth(drawSet, drawSet.GlobalPointer->RenderedInstanceContainers[i], drawParameter))
								continue;

							drawSet.GlobalPointer->RenderedInstanceContainers[i]->Draw(false);
						}
					}
					else
					{
						drawSet.InstanceContainerPointer->Draw(true);
					}
				}
			}
		}
		else
		{
			if (drawSet.IsShown)
			{
				if (drawSet.GlobalPointer->RenderedInstanceContainers.size() > 0)
				{
					for (size_t i = e->renderingNodesThreshold; i < drawSet.GlobalPointer->RenderedInstanceContainers.size(); i++)
					{
						if (IsClippedWithDepth(drawSet, drawSet.GlobalPointer->RenderedInstanceContainers[i], drawParameter))
							continue;

						drawSet.GlobalPointer->RenderedInstanceContainers[i]->Draw(false);
					}
				}
				else
				{
					drawSet.InstanceContainerPointer->Draw(true);
				}
			}
		}
	}
}

int ManagerImplemented::GetUpdateTime() const
{
	return m_updateTime;
};

int ManagerImplemented::GetDrawTime() const
{
	return m_drawTime;
};

int32_t ManagerImplemented::GetRestInstancesCount() const
{
	return static_cast<int32_t>(pooledChunks_.size()) * InstanceChunk::InstancesOfChunk;
}

void ManagerImplemented::BeginReloadEffect(const EffectRef& effect, bool doLockThread)
{
	if (doLockThread)
	{
		m_renderingMutex.lock();
		m_isLockedWithRenderingMutex = true;
	}

	for (auto& it : m_DrawSets)
	{
		if (it.second.ParameterPointer != effect)
			continue;

		if (it.second.InstanceContainerPointer == nullptr)
		{
			continue;
		}

		// dispose instances
		StopWithoutRemoveDrawSet(it.second);
	}
}

void ManagerImplemented::EndReloadEffect(const EffectRef& effect, bool doLockThread)
{
	for (auto& it : m_DrawSets)
	{
		auto& ds = it.second;

		if (ds.ParameterPointer != effect)
			continue;

		if (it.second.InstanceContainerPointer != nullptr)
		{
			continue;
		}

		ResetAndPlayWithDataSet(ds, ds.GlobalPointer->GetUpdatedFrame());
	}

	Flip();

	if (doLockThread)
	{
		m_renderingMutex.unlock();
		m_isLockedWithRenderingMutex = false;
	}
}

void ManagerImplemented::CreateCullingWorld(float xsize, float ysize, float zsize, int32_t layerCount)
{
	cullingNext.SizeX = xsize;
	cullingNext.SizeY = ysize;
	cullingNext.SizeZ = zsize;
	cullingNext.LayerCount = layerCount;
}

void ManagerImplemented::CalcCulling(const Matrix44& cameraProjMat, bool isOpenGL)
{
	if (m_cullingWorld == nullptr)
		return;

	m_culledObjects.clear();
	m_culledObjectSets.clear();

	Matrix44 mat = cameraProjMat;
	mat.Transpose();

	Culling3D::Matrix44 cullingMat;

	for (int32_t c = 0; c < 4; c++)
	{
		for (int32_t r = 0; r < 4; r++)
		{
			cullingMat.Values[c][r] = mat.Values[c][r];
		}
	}

	m_cullingWorld->Culling(cullingMat, isOpenGL);

	for (int32_t i = 0; i < m_cullingWorld->GetObjectCount(); i++)
	{
		Culling3D::Object* o = m_cullingWorld->GetObject(i);
		DrawSet* ds = (DrawSet*)o->GetUserData();

		m_culledObjects.push_back(ds);
		m_culledObjectSets.insert(ds->Self);
	}

	// sort with handle
	std::sort(m_culledObjects.begin(), m_culledObjects.end(), [](DrawSet* const& lhs, DrawSet* const& rhs) { return lhs->Self < rhs->Self; });

	m_culled = true;
}

void ManagerImplemented::RessignCulling()
{
	if (m_cullingWorld == nullptr)
		return;

	m_culledObjects.clear();
	m_culledObjectSets.clear();

	m_cullingWorld->Reassign();
}

void ManagerImplemented::LockRendering()
{
	m_renderingMutex.lock();
}

void ManagerImplemented::UnlockRendering()
{
	m_renderingMutex.unlock();
}

void ManagerImplemented::RequestToPlaySound(Instance* instance, const EffectNodeImplemented* node)
{
	if (node->Sound.WaveId >= 0)
	{
		InstanceGlobal* instanceGlobal = instance->GetInstanceGlobal();
		IRandObject& rand = instance->GetRandObject();

		SoundPlayer::InstanceParameter parameter;
		parameter.Data = node->GetEffect()->GetWave(node->Sound.WaveId);
		parameter.Volume = node->Sound.Volume.getValue(rand);
		parameter.Pitch = node->Sound.Pitch.getValue(rand);
		parameter.Pan = node->Sound.Pan.getValue(rand);

		parameter.Mode3D = (node->Sound.PanType == ParameterSoundPanType_3D);
		parameter.Position = ToStruct(instance->GetGlobalMatrix43().GetTranslation());
		parameter.Distance = node->Sound.Distance;
		parameter.UserData = instanceGlobal->GetUserData();

		std::lock_guard<std::mutex> lock(m_soundMutex);
		m_requestedSounds.emplace(static_cast<SoundTag>(instanceGlobal), parameter);
	}
}

void ManagerImplemented::ExecuteSounds()
{
	if (m_requestedSounds.empty())
	{
		return;
	}

	std::lock_guard<std::mutex> lock(m_soundMutex);

	auto player = GetSoundPlayer();
	if (player != nullptr)
	{
		while (!m_requestedSounds.empty())
		{
			auto sound = m_requestedSounds.back();
			player->Play(sound.first, sound.second);
			m_requestedSounds.pop();
		}
	}
	else
	{
		while (!m_requestedSounds.empty())
		{
			m_requestedSounds.pop();
		}
	}
}

} // namespace Effekseer
