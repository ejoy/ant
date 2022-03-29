
#pragma once

#include "efkMat.Base.h"
#include "efkMat.Utils.h"
#include <set>

namespace EffekseerMaterial
{

enum class LanguageType
{
	Japanese,
	English,
	Max,
};

class CommandManager;

class UserObject
{
public:
	UserObject() = default;
	virtual ~UserObject() = default;
};

class Link
{
public:
	std::shared_ptr<Pin> InputPin;
	std::shared_ptr<Pin> OutputPin;

	//! For visualization
	uint64_t GUID = 0;
};

class Pin
{
public:
	std::shared_ptr<PinParameter> Parameter;
	std::weak_ptr<Node> Parent;

	//! to make easy to access
	PinDirectionType PinDirection;

	//! to make easy to access
	int32_t PinIndex;

	//! For visualization
	uint64_t GUID = 0;

	//! whether is this pin enabled.
	bool IsEnabled = true;
};

class NodeProperty
{
public:
	//! Values, bool, isTextureValue(Normal)
	std::array<float, 4> Floats;

	//! String, Texture Path
	std::string Str;

	//! Function
	std::shared_ptr<Material> MaterialFunction;

	std::weak_ptr<Node> Parent;
};

struct NodeDescription
{
public:
	std::string Summary;
	std::string Detail;
};

class Node : public std::enable_shared_from_this<Node>
{
private:
	friend class Material;
	bool isDirtied = true;
	bool isContentDirtied = false;
	bool isPosDirtied_ = true;

	std::weak_ptr<Material> material_;

public:
	std::shared_ptr<NodeParameter> Parameter;
	std::vector<std::shared_ptr<Pin>> InputPins;
	std::vector<std::shared_ptr<Pin>> OutputPins;
	std::vector<std::shared_ptr<NodeProperty>> Properties;

	//! For visualization
	uint64_t GUID = 0;

	//! For visualization
	Vector2DF Pos;

	//! For visualization (comment)
	Vector2DF CommentSize = Vector2DF(0, 0);

	//! is node opened and show a preview
	bool IsPreviewOpened = false;

	//! descriptons for other editors
	std::vector<std::shared_ptr<NodeDescription>> Descriptions;

	//! warning
	WarningType CurrentWarning = WarningType::None;

	//! For gui
	std::shared_ptr<UserObject> UserObj;

	std::weak_ptr<Material> Parent;

	int32_t GetInputPinIndex(const std::string& name);

	int32_t GetOutputPinIndex(const std::string& name);

	std::shared_ptr<NodeProperty> GetProperty(const std::string& name) const;

	void UpdateRegion(const Vector2DF& pos, const Vector2DF& size);

	bool GetIsPosDirtied() const { return isPosDirtied_; }

	bool GetIsDirtied() const { return isDirtied; }

	bool GetIsContentDirtied() const { return isContentDirtied; }

	void MakePosDirtied() { isPosDirtied_ = true; }

	void ClearPosDirtied() { isPosDirtied_ = false; }

	Node() {}
};

class TextureInfo : public std::enable_shared_from_this<TextureInfo>
{
public:
	TextureInfo() {}

	virtual ~TextureInfo() {}

	std::string Path;
	TextureValueType Type = TextureValueType::Color;
};

class CustomDataProperty
{
public:
	CustomDataProperty() { Values.fill(0.0f); }

	virtual ~CustomDataProperty() {}

	//! descriptons for other editors
	std::vector<std::shared_ptr<NodeDescription>> Descriptions;

	std::array<float, 4> Values;
};

enum class ErrorCode
{
	OK,
	InvalidFile,
	NotFound,
	NewVersion,
};

class Material : public std::enable_shared_from_this<Material>
{
private:
	const int32_t lastestSupportedVersion_ = MaterialVersion16;

	enum class SaveLoadAimType
	{
		IO,
		CopyOrPaste,
	};

	std::string path_;

	std::vector<std::shared_ptr<Node>> nodes_;
	std::vector<std::shared_ptr<Link>> links_;
	std::map<std::string, std::shared_ptr<TextureInfo>> textures;

	uint64_t nextGUID = 0xff;

	uint64_t GetIDAndNext();

	std::shared_ptr<CommandManager> commandManager_;

	bool FindLoop(std::shared_ptr<Pin> pin1, std::shared_ptr<Pin> pin2);

	std::string SaveAsStrInternal(std::vector<std::shared_ptr<Node>> nodes,
								  std::vector<std::shared_ptr<Link>> links,
								  const char* basePath,
								  SaveLoadAimType aim);

	void
	LoadFromStrInternal(const char* json, Vector2DF offset, std::shared_ptr<Library> library, const char* basePath, SaveLoadAimType aim);

public:
	Material();

	virtual ~Material();

	const std::string& GetPath() const;

	void SetPath(const std::string& path);

	void Initialize();

	std::vector<std::shared_ptr<Pin>> GetConnectedPins(std::shared_ptr<Pin> pin);

	std::unordered_set<std::shared_ptr<Pin>> GetRelatedPins(std::shared_ptr<Pin> pin);

	ValueType GetPinType(DefaultType type);

	ValueType GetDesiredPinType(std::shared_ptr<Pin> pin, std::unordered_set<std::shared_ptr<Pin>>& visited);

	std::shared_ptr<Node> CreateNode(std::shared_ptr<NodeParameter> parameter, bool isDirectly, uint64_t guid = 0);

	void RemoveNode(std::shared_ptr<Node> node);

	ConnectResultType CanConnectPin(std::shared_ptr<Pin> pin1, std::shared_ptr<Pin> pin2);

	ConnectResultType ConnectPin(std::shared_ptr<Pin> pin1, std::shared_ptr<Pin> pin2);

	bool BreakPin(std::shared_ptr<Link> link);

	const std::vector<std::shared_ptr<Node>>& GetNodes() const;

	const std::vector<std::shared_ptr<Link>>& GetLinks() const;

	const std::map<std::string, std::shared_ptr<TextureInfo>> GetTextures() const;

	std::shared_ptr<Node> FindNode(uint64_t guid);

	std::shared_ptr<Link> FindLink(uint64_t guid);

	std::shared_ptr<Pin> FindPin(uint64_t guid);

	std::shared_ptr<TextureInfo> FindTexture(const char* path);

	std::string Copy(std::vector<std::shared_ptr<Node>> nodes, const char* basePath);

	void Paste(std::string content, const Vector2DF& pos, std::shared_ptr<Library> library, const char* basePath);

	void ApplyMoveNodesMultiply(std::vector<std::shared_ptr<Node>> nodes, std::vector<Vector2DF>& poses);

	void ChangeValue(std::shared_ptr<NodeProperty> prop, std::array<float, 4> value);

	void ChangeValue(std::shared_ptr<NodeProperty> prop, std::string value);

	void ChangeValueTextureType(std::shared_ptr<TextureInfo> prop, TextureValueType type);

	void MakeDirty(std::shared_ptr<Node> node, bool doesUpdateWarnings = true);

	void ClearDirty(std::shared_ptr<Node> node);

	void MakeContentDirty(std::shared_ptr<Node> node);

	void ClearContentDirty(std::shared_ptr<Node> node);

	void UpdateWarnings();

	void LoadFromStr(const char* json, std::shared_ptr<Library> library, const char* basePath);

	std::string SaveAsStr(const char* basePath);

	ErrorCode Load(std::vector<uint8_t>& data, std::shared_ptr<Library> library, const char* basePath);

	bool Save(std::vector<uint8_t>& data, const char* basePath);

	LanguageType Language = LanguageType::Japanese;

	std::array<CustomDataProperty, 2> CustomData;

	std::shared_ptr<CommandManager> GetCommandManager() { return commandManager_; }
};

} // namespace EffekseerMaterial
