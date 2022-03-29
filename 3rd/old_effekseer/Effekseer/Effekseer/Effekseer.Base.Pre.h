
#ifndef __EFFEKSEER_BASE_PRE_H__
#define __EFFEKSEER_BASE_PRE_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include <array>
#include <assert.h>
#include <atomic>
#include <cfloat>
#include <climits>
#include <functional>
#include <memory>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <string>
#include <thread>
#include <vector>

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#ifdef _WIN32
#define EFK_STDCALL __stdcall
#else
#define EFK_STDCALL
#endif

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------

#ifdef _WIN32
//#include <windows.h>
#elif defined(_PSVITA)
#elif defined(_PS4)
#elif defined(_SWITCH)
#elif defined(_XBOXONE)
#else
#include <pthread.h>
#include <sys/time.h>
#include <unistd.h>
#endif

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
typedef char16_t EFK_CHAR;

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
struct Vector2D;
struct Vector3D;
struct Matrix43;
struct Matrix44;
struct RectF;

class Setting;
class Manager;
class Effect;
class EffectNode;

class SpriteRenderer;
class RibbonRenderer;
class RingRenderer;
class ModelRenderer;
class TrackRenderer;

class EffectLoader;
class TextureLoader;
class MaterialLoader;
class SoundLoader;
class ModelLoader;
class CurveLoader;

class Texture;
class SoundData;
class SoundPlayer;
class Model;
struct ProceduralModelParameter;
class ProceduralModelGenerator;
class Curve;
class Material;

typedef int Handle;

class ManagerImplemented;
class EffectImplemented;

namespace Backend
{
class Texture;
}

using ThreadNativeHandleType = std::thread::native_handle_type;

/**
	@brief	Memory Allocation function
*/
typedef void*(EFK_STDCALL* MallocFunc)(unsigned int size);

/**
	@brief	Memory Free function
*/
typedef void(EFK_STDCALL* FreeFunc)(void* p, unsigned int size);

/**
	@brief	AlignedMemory Allocation function
*/
typedef void*(EFK_STDCALL* AlignedMallocFunc)(unsigned int size, unsigned int alignment);

/**
	@brief	AlignedMemory Free function
*/
typedef void(EFK_STDCALL* AlignedFreeFunc)(void* p, unsigned int size);

/**
	@brief	Random Function
*/
typedef int(EFK_STDCALL* RandFunc)(void);

/**
	@brief	エフェクトのインスタンス破棄時のコールバックイベント
	@param	manager	[in]	所属しているマネージャー
	@param	handle	[in]	エフェクトのインスタンスのハンドル
	@param	isRemovingManager	[in]	マネージャーを破棄したときにエフェクトのインスタンスを破棄しているか
*/
typedef void(EFK_STDCALL* EffectInstanceRemovingCallback)(Manager* manager, Handle handle, bool isRemovingManager);

#define ES_SAFE_ADDREF(val)                                                                     \
	static_assert(std::is_class<decltype(val)>::value != true, "val must not be class/struct"); \
	if ((val) != nullptr)                                                                       \
	{                                                                                           \
		(val)->AddRef();                                                                        \
	}
#define ES_SAFE_RELEASE(val)                                                                    \
	static_assert(std::is_class<decltype(val)>::value != true, "val must not be class/struct"); \
	if ((val) != nullptr)                                                                       \
	{                                                                                           \
		(val)->Release();                                                                       \
		(val) = nullptr;                                                                        \
	}

#define ES_SAFE_DELETE(val)                                                                     \
	static_assert(std::is_class<decltype(val)>::value != true, "val must not be class/struct"); \
	if ((val) != nullptr)                                                                       \
	{                                                                                           \
		delete (val);                                                                           \
		(val) = nullptr;                                                                        \
	}
#define ES_SAFE_DELETE_ARRAY(val)                                                               \
	static_assert(std::is_class<decltype(val)>::value != true, "val must not be class/struct"); \
	if ((val) != nullptr)                                                                       \
	{                                                                                           \
		delete[](val);                                                                          \
		(val) = nullptr;                                                                        \
	}

#define EFK_ASSERT(x) assert(x)

//! the maximum number of texture slot which can be specified by an user
const int32_t UserTextureSlotMax = 6;

//! the maximum number of texture slot including textures system specified
const int32_t TextureSlotMax = 8;

const int32_t LocalFieldSlotMax = 4;

const float EFK_PI = 3.141592653589f;

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
/**
	@brief	アルファブレンド
*/
enum class AlphaBlendType : int32_t
{
	/// <summary>
	/// 不透明
	/// </summary>
	Opacity = 0,
	/// <summary>
	/// 透明
	/// </summary>
	Blend = 1,
	/// <summary>
	/// 加算
	/// </summary>
	Add = 2,
	/// <summary>
	/// 減算
	/// </summary>
	Sub = 3,
	/// <summary>
	/// 乗算
	/// </summary>
	Mul = 4,
};

enum class TextureFilterType : int32_t
{
	Nearest = 0,
	Linear = 1,
};

enum class TextureWrapType : int32_t
{
	Repeat = 0,
	Clamp = 1,
};

enum class CullingType : int32_t
{
	Front = 0,
	Back = 1,
	Double = 2,
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
enum class BillboardType : int32_t
{
	Billboard = 0,
	YAxisFixed = 1,
	Fixed = 2,
	RotatedBillboard = 3,
};

enum class CoordinateSystem : int32_t
{
	LH,
	RH,
};

enum class CullingShape : int32_t
{
	NoneShape = 0,
	Sphere = 1,
};

enum class TextureType : int32_t
{
	Color,
	Normal,
	Distortion,
};

enum class MaterialFileType : int32_t
{
	Code,
	Compiled,
};

enum class TextureFormatType : int32_t
{
	ABGR8,
	BC1,
	BC2,
	BC3,
};

enum class ZSortType : int32_t
{
	None,
	NormalOrder,
	ReverseOrder,
};

//-----------------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------------
enum class RenderMode : int32_t
{
	Normal,	   // 通常描画
	Wireframe, // ワイヤーフレーム描画
};

/**
	@brief
	\~English	A thread where reload function is called
	\~Japanese	リロードの関数が呼ばれるスレッド
*/
enum class ReloadingThreadType
{
	Main,
	Render,
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
/**
	@brief	最大値取得
*/
template <typename T, typename U>
T Max(T t, U u)
{
	if (t > (T)u)
	{
		return t;
	}
	return u;
}

/**
	@brief	最小値取得
*/
template <typename T, typename U>
T Min(T t, U u)
{
	if (t < (T)u)
	{
		return t;
	}
	return u;
}

/**
	@brief	範囲内値取得
*/
template <typename T, typename U, typename V>
T Clamp(T t, U max_, V min_)
{
	if (t > (T)max_)
	{
		t = (T)max_;
	}

	if (t < (T)min_)
	{
		t = (T)min_;
	}

	return t;
}

/**
    @brief    Convert UTF16 into UTF8
    @param    dst    a pointer to destination buffer
    @param    dst_size    a length of destination buffer
    @param    src            a source buffer
    @return    length except 0
*/
inline int32_t ConvertUtf16ToUtf8(char* dst, int32_t dst_size, const char16_t* src)
{
	int32_t cnt = 0;
	const char16_t* wp = src;
	char* cp = dst;

	if (dst_size == 0)
		return 0;

	dst_size -= 3;

	for (cnt = 0; cnt < dst_size;)
	{
		char16_t wc = *wp++;
		if (wc == 0)
		{
			break;
		}
		if ((wc & ~0x7f) == 0)
		{
			*cp++ = wc & 0x7f;
			cnt += 1;
		}
		else if ((wc & ~0x7ff) == 0)
		{
			*cp++ = ((wc >> 6) & 0x1f) | 0xc0;
			*cp++ = ((wc)&0x3f) | 0x80;
			cnt += 2;
		}
		else
		{
			*cp++ = ((wc >> 12) & 0xf) | 0xe0;
			*cp++ = ((wc >> 6) & 0x3f) | 0x80;
			*cp++ = ((wc)&0x3f) | 0x80;
			cnt += 3;
		}
	}
	*cp = '\0';
	return cnt;
}

/**
    @brief    Convert UTF8 into UTF16
    @param    dst    a pointer to destination buffer
    @param    dst_size    a length of destination buffer
    @param    src            a source buffer
    @return    length except 0
*/
inline int32_t ConvertUtf8ToUtf16(char16_t* dst, int32_t dst_size, const char* src)
{
	int32_t i, code = 0;
	int8_t c0, c1, c2 = 0;
	int8_t* srci = reinterpret_cast<int8_t*>(const_cast<char*>(src));
	if (dst_size == 0)
		return 0;

	dst_size -= 1;

	for (i = 0; i < dst_size; i++)
	{
		uint16_t wc;

		c0 = *srci;
		srci++;
		if (c0 == '\0')
		{
			break;
		}
		// convert UTF8 to UTF16
		code = (uint8_t)c0 >> 4;
		if (code <= 7)
		{
			// 8bit character
			wc = c0;
		}
		else if (code >= 12 && code <= 13)
		{
			// 16bit  character
			c1 = *srci;
			srci++;
			wc = ((c0 & 0x1F) << 6) | (c1 & 0x3F);
		}
		else if (code == 14)
		{
			// 24bit character
			c1 = *srci;
			srci++;
			c2 = *srci;
			srci++;
			wc = ((c0 & 0x0F) << 12) | ((c1 & 0x3F) << 6) | (c2 & 0x3F);
		}
		else
		{
			continue;
		}
		dst[i] = wc;
	}
	dst[i] = 0;
	return i;
}

/**
	@brief	\~english	An interface of reference counter
			\~japanese	参照カウンタのインターフェース
*/
class IReference
{
public:
	/**
	@brief	参照カウンタを加算する。
	@return	加算後の参照カウンタ
	*/
	virtual int AddRef() = 0;

	/**
	@brief	参照カウンタを取得する。
	@return	参照カウンタ
	*/
	virtual int GetRef() = 0;

	/**
	@brief	参照カウンタを減算する。0になった時、インスタンスを削除する。
	@return	減算後の参照カウンタ
	*/
	virtual int Release() = 0;
};

/**
	@brief	\~english	A reference counter
			\~japanese	参照カウンタ
*/
class ReferenceObject : public IReference
{
private:
	mutable std::atomic<int32_t> m_reference;

public:
	ReferenceObject()
		: m_reference(1)
	{
	}

	virtual ~ReferenceObject()
	{
	}

	virtual int AddRef()
	{
		std::atomic_fetch_add_explicit(&m_reference, 1, std::memory_order_consume);

		return m_reference;
	}

	virtual int GetRef()
	{
		return m_reference;
	}

	virtual int Release()
	{
		bool destroy = std::atomic_fetch_sub_explicit(&m_reference, 1, std::memory_order_consume) == 1;
		if (destroy)
		{
			delete this;
			return 0;
		}

		return m_reference;
	}
};

/**
	@brief	a deleter for IReference
*/
template <typename T>
struct ReferenceDeleter
{
	void operator()(T* ptr) const
	{
		if (ptr != nullptr)
		{
			ptr->Release();
		}
	}
};

template <typename T>
inline std::unique_ptr<T, ReferenceDeleter<T>> CreateUniqueReference(T* ptr, bool addRef = false)
{
	if (ptr == nullptr)
		return std::unique_ptr<T, ReferenceDeleter<T>>(nullptr);

	if (addRef)
	{
		ptr->AddRef();
	}

	return std::unique_ptr<T, ReferenceDeleter<T>>(ptr);
}

template <typename T>
inline std::shared_ptr<T> CreateReference(T* ptr, bool addRef = false)
{
	if (ptr == nullptr)
		return std::shared_ptr<T>(nullptr);

	if (addRef)
	{
		ptr->AddRef();
	}

	return std::shared_ptr<T>(ptr, ReferenceDeleter<T>());
}

template <typename T>
inline void SafeAddRef(T* val)
{
	if (val != nullptr)
	{
		val->AddRef();
	}
}

template <typename T>
inline void SafeRelease(T*& val)
{
	if (val != nullptr)
	{
		val->Release();
		val = nullptr;
	}
}

/**
	@brief	\~english	A smart pointer for reference counter
			\~japanese	参照カウンタ向けスマートポインタ
*/
template <typename T>
class RefPtr
{
	T* ptr_ = nullptr;

	template <typename U>
	friend class RefPtr;

public:
	RefPtr() = default;

	explicit RefPtr(T* p)
	{
		ptr_ = p;
	}

	RefPtr(std::nullptr_t)
	{
		ptr_ = nullptr;
	}

	~RefPtr()
	{
		SafeRelease(ptr_);
	}

	RefPtr(const RefPtr<T>& o)
	{
		SafeAddRef(o.ptr_);
		SafeRelease(ptr_);
		ptr_ = o.ptr_;
	}

	void Reset()
	{
		SafeRelease(ptr_);
	}

	T* operator->() const
	{
		return Get();
	}

	T* Get() const
	{
		return ptr_;
	}

	RefPtr<T>& operator=(const RefPtr<T>& o)
	{
		SafeAddRef(o.ptr_);
		SafeRelease(ptr_);
		ptr_ = o.ptr_;
		return *this;
	}

	template <class U>
	void operator=(const RefPtr<U>& o)
	{
		auto ptr = o.Get();
		SafeAddRef(ptr);
		SafeRelease(ptr_);
		ptr_ = ptr;
	}

	template <class U>
	void operator=(RefPtr<U>&& o)
	{
		auto ptr = o.Get();
		o.ptr_ = nullptr;
		SafeRelease(ptr_);
		ptr_ = ptr;
	}

	template <class U>
	RefPtr(const RefPtr<U>& o)
	{
		auto ptr = o.Get();
		SafeAddRef(ptr);
		SafeRelease(ptr_);
		ptr_ = ptr;
	}

	template <class U>
	RefPtr(RefPtr<U>&& o)
	{
		auto ptr = o.Get();
		o.ptr_ = nullptr;
		SafeRelease(ptr_);
		ptr_ = ptr;
	}

	template <class U>
	RefPtr<U> DownCast()
	{
		auto ptr = Get();
		SafeAddRef(ptr);
		return RefPtr<U>(static_cast<U*>(ptr));
	}

	void* Pin()
	{
		SafeAddRef(ptr_);
		return ptr_;
	}

	static void Unpin(void* p)
	{
		auto ptr = reinterpret_cast<T*>(p);
		SafeRelease(ptr);
	}

	static RefPtr<T> FromPinned(void* p)
	{
		auto ptr = reinterpret_cast<T*>(p);
		SafeAddRef(ptr);
		return RefPtr<T>(ptr);
	}
};

template <class T, class U>
inline bool operator==(const RefPtr<T>& lhs, const RefPtr<U>& rhs)
{
	return lhs.Get() == rhs.Get();
}
template <class T, class U>
inline bool operator!=(const RefPtr<T>& lhs, const RefPtr<U>& rhs)
{
	return lhs.Get() != rhs.Get();
}

template <class T>
inline bool operator<(const RefPtr<T>& lhs, const RefPtr<T>& rhs)
{
	return lhs.Get() < rhs.Get();
}

template <class T>
inline bool operator==(const RefPtr<T>& lhs, const std::nullptr_t& rhs)
{
	return lhs.Get() == rhs;
}
template <class T>
inline bool operator!=(const RefPtr<T>& lhs, const std::nullptr_t& rhs)
{
	return lhs.Get() != rhs;
}

template <class T, class... Arg>
RefPtr<T> MakeRefPtr(Arg&&... args)
{
	return RefPtr<T>(new T(args...));
}

using SettingRef = RefPtr<Setting>;
using ManagerRef = RefPtr<Manager>;
using EffectRef = RefPtr<Effect>;
using TextureRef = RefPtr<Texture>;
using SoundDataRef = RefPtr<SoundData>;
using ModelRef = RefPtr<Model>;
using MaterialRef = RefPtr<Material>;
using CurveRef = RefPtr<Curve>;

using SpriteRendererRef = RefPtr<SpriteRenderer>;
using RibbonRendererRef = RefPtr<RibbonRenderer>;
using RingRendererRef = RefPtr<RingRenderer>;
using ModelRendererRef = RefPtr<ModelRenderer>;
using TrackRendererRef = RefPtr<TrackRenderer>;
using SoundPlayerRef = RefPtr<SoundPlayer>;

using EffectLoaderRef = RefPtr<EffectLoader>;
using TextureLoaderRef = RefPtr<TextureLoader>;
using MaterialLoaderRef = RefPtr<MaterialLoader>;
using SoundLoaderRef = RefPtr<SoundLoader>;
using ModelLoaderRef = RefPtr<ModelLoader>;
using CurveLoaderRef = RefPtr<CurveLoader>;
using ProceduralModelGeneratorRef = RefPtr<ProceduralModelGenerator>;

/**
	@brief	This object generates random values.
*/
class IRandObject
{
public:
	IRandObject() = default;
	virtual ~IRandObject() = default;

	virtual int32_t GetRandInt() = 0;

	virtual float GetRand() = 0;

	virtual float GetRand(float min_, float max_) = 0;
};

template <typename T, size_t N>
struct FixedSizeVector
{
private:
	std::array<T, N> internal_;
	size_t size_ = 0;

public:
	T& at(size_t n)
	{
		assert(n < size_);
		return internal_.at(n);
	}

	const T& at(size_t n) const
	{
		assert(n < size_);

		return internal_.at(n);
	}

	const T* data() const
	{
		return internal_.data();
	}

	void resize(size_t nsize)
	{
		assert(nsize <= internal_.size());
		size_ = nsize;
	}

	bool operator==(FixedSizeVector<T, N> const& rhs) const
	{
		if (size_ != rhs.size_)
			return false;

		for (size_t i = 0; i < size_; i++)
		{
			if (internal_[i] != rhs.internal_[i])
				return false;
		}

		return true;
	}

	bool operator!=(FixedSizeVector<T, N> const& rhs) const
	{
		return !(*this == rhs);
	}

	size_t size() const
	{
		return size_;
	}

	size_t get_hash() const
	{
		auto h = std::hash<size_t>()(size());
		for (size_t i = 0; i < size(); i++)
		{
			h += std::hash<T>()(at(i));
		}
		return h;
	}
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------

enum class LogType
{
	Info,
	Warning,
	Error,
	Debug,
};

void SetLogger(const std::function<void(LogType, const std::string&)>& logger);

void Log(LogType logType, const std::string& message);

enum class ColorSpaceType : int32_t
{
	Gamma,
	Linear,
};

enum class ShadingModelType : int32_t
{
	Lit,
	Unlit,
};

/**
	@brief	material type
*/
enum class RendererMaterialType : int32_t
{
	Default = 0,
	BackDistortion = 6,
	Lighting = 7,
	File = 128,
};

/**
	@brief	\~english	Textures used by material
			\~japanese	マテリアルに使用されるテクスチャ
*/
struct MaterialTextureParameter
{
	//! 0 - color, 1 - value
	int32_t Type = 0;
	int32_t Index = 0;
};

/**
	@brief	\~english	Material parameter for shaders
			\~japanese	シェーダー向けマテリアルパラメーター
*/
struct MaterialRenderData
{
	//! material index in MaterialType::File
	int32_t MaterialIndex = -1;

	//! used textures in MaterialType::File
	std::vector<MaterialTextureParameter> MaterialTextures;

	//! used uniforms in MaterialType::File
	std::vector<std::array<float, 4>> MaterialUniforms;
};

/**
	@brief	\~english	Parameters about a depth which is passed into a renderer
			\~japanese	レンダラーに渡されるデプスに関するパラメーター
*/
struct NodeRendererDepthParameter
{
	float DepthOffset = 0.0f;
	bool IsDepthOffsetScaledWithCamera = false;
	bool IsDepthOffsetScaledWithParticleScale = false;
	ZSortType ZSort = ZSortType::None;
	float SuppressionOfScalingByDepth = 1.0f;
	float DepthClipping = FLT_MAX;
};

/**
	@brief	\~english	Common parameters which is passed into a renderer
			\~japanese	レンダラーに渡される共通に関するパラメーター
*/
struct NodeRendererBasicParameter
{
	RendererMaterialType MaterialType = RendererMaterialType::Default;

	std::array<int32_t, TextureSlotMax> TextureIndexes;

	float DistortionIntensity = 0.0f;
	MaterialRenderData* MaterialRenderDataPtr = nullptr;
	AlphaBlendType AlphaBlend = AlphaBlendType::Blend;

	std::array<TextureFilterType, TextureSlotMax> TextureFilters;
	std::array<TextureWrapType, TextureSlotMax> TextureWraps;

	float UVDistortionIntensity = 1.0f;

	int32_t TextureBlendType = -1;

	float BlendUVDistortionIntensity = 1.0f;

	bool EnableInterpolation = false;
	int32_t UVLoopType = 0;
	int32_t InterpolationType = 0;
	int32_t FlipbookDivideX = 1;
	int32_t FlipbookDivideY = 1;

	float EmissiveScaling = 1.0f;

	float EdgeThreshold = 0.0f;
	uint8_t EdgeColor[4] = {0};
	float EdgeColorScaling = 1.0f;

	//! copy from alphacutoff
	bool IsAlphaCutoffEnabled = false;

	float SoftParticleDistanceFar = 0.0f;
	float SoftParticleDistanceNear = 0.0f;
	float SoftParticleDistanceNearOffset = 0.0f;

	NodeRendererBasicParameter()
	{
		TextureIndexes.fill(-1);
		TextureFilters.fill(TextureFilterType::Nearest);
		TextureWraps.fill(TextureWrapType::Repeat);
	}

	//! Whether are particles rendered with AdvancedRenderer
	bool GetIsRenderedWithAdvancedRenderer() const
	{
		if (MaterialType == RendererMaterialType::File)
			return false;

		for (size_t i = 2; i < TextureIndexes.size(); i++)
		{
			if (TextureIndexes[i] >= 0)
			{
				return true;
			}
		}

		if (EnableInterpolation)
			return true;

		if (TextureBlendType != -1)
			return true;

		if (EdgeThreshold != 0)
			return true;

		if (IsAlphaCutoffEnabled)
			return true;

		return false;
	}
};

/**
	@brief
	\~English	A user data for rendering in plugins.
	\~Japanese	プラグイン向けの描画拡張データ
*/
class RenderingUserData : public ReferenceObject
{
public:
	RenderingUserData() = default;
	virtual ~RenderingUserData() = default;

	virtual bool Equal(const RenderingUserData* rhs) const
	{
		return true;
	}
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#endif // __EFFEKSEER_BASE_PRE_H__
