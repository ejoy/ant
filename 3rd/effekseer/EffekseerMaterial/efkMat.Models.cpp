#include "efkMat.Models.h"
#include "ThirdParty/picojson.h"
#include "efkMat.CommandManager.h"
#include "efkMat.Library.h"
#include "efkMat.Parameters.h"
#include "efkMat.TextExporter.h"
#include <float.h>
#include <cstring>

std::vector<std::string> Split(const std::string& s, char delim)
{
	std::vector<std::string> elems;
	std::stringstream ss(s);
	std::string item;
	while (getline(ss, item, delim))
	{
		if (!item.empty())
		{
			elems.push_back(item);
		}
	}
	return elems;
}

std::string Replace(std::string target, std::string from_, std::string to_)
{
	std::string::size_type Pos(target.find(from_));

	while (Pos != std::string::npos)
	{
		target.replace(Pos, from_.length(), to_);
		Pos = target.find(from_, Pos + to_.length());
	}

	return target;
}

namespace EffekseerMaterial
{

class BinaryWriter
{
	std::vector<uint8_t> buffer_;

public:
	template <typename T> void Push(T value)
	{
		auto offset = buffer_.size();
		buffer_.resize(offset + sizeof(T));
		std::memcpy(buffer_.data() + offset, &value, sizeof(T));
	}

	template <typename U> void Push(const std::vector<U>& value)
	{
		Push(static_cast<int32_t>(value.size()));
		auto offset = buffer_.size();
		buffer_.resize(offset + sizeof(U) * value.size());
		std::memcpy(buffer_.data() + offset, value.data(), sizeof(U) * value.size());
	}

	const std::vector<uint8_t>& GetBuffer() const { return buffer_; }
};

template <> void BinaryWriter::Push<bool>(bool value)
{
	int32_t temp = value ? 1 : 0;
	Push(temp);
}

static const char* tag_changeNumberCommand = "ChangeNumberCommand";

static const char* tag_changeStringCommand = "ChangeStringCommand";

static const char* tag_changeNodePosCommand = "ChangeNodePosCommand";

static const char* tag_changeMultiNodePosCommand = "ChangeMultiNodePosCommand";

static const char* tag_changeNodeCommentSizeCommand = "ChangeNodeCommentSizeCommand";

static std::vector<char> GetVectorFromStr(const std::string& s)
{
	std::vector<char> ret;
	ret.resize(s.size() + 1);
	std::copy(s.begin(), s.end(), ret.begin());
	ret[ret.size() - 1] = 0;
	return ret;
}

class ChangeNumberCommand : public ICommand
{
private:
	std::shared_ptr<NodeProperty> prop_;
	std::array<float, 4> newValue_;
	std::array<float, 4> oldValue_;

public:
	ChangeNumberCommand(std::shared_ptr<NodeProperty> prop, std::array<float, 4> newValue, std::array<float, 4> oldValue)
		: prop_(prop), newValue_(newValue), oldValue_(oldValue)
	{
	}

	virtual ~ChangeNumberCommand() {}

	void Execute() override { prop_->Floats = newValue_; }

	void Unexecute() override
	{
		prop_->Floats = oldValue_;

		auto parent = prop_->Parent.lock();

		if (parent != nullptr)
		{
			auto parentMaterial = parent->Parent.lock();

			if (parentMaterial != nullptr)
			{
				parentMaterial->MakeDirty(parent);
			}
		}
	}

	bool Merge(ICommand* command)
	{

		if (command->GetTag() != this->GetTag())
			return false;

		auto command_ = static_cast<ChangeNumberCommand*>(command);
		if (command_->prop_ != this->prop_)
			return false;

		this->oldValue_ = command_->oldValue_;

		return true;
	}

	virtual const char* GetTag() { return tag_changeNumberCommand; }
};

class ChangeStringCommand : public ICommand
{
private:
	std::shared_ptr<NodeProperty> prop_;
	std::string newValue_;
	std::string oldValue_;

public:
	ChangeStringCommand(std::shared_ptr<NodeProperty> prop, std::string newValue, std::string oldValue)
		: prop_(prop), newValue_(newValue), oldValue_(oldValue)
	{
	}

	virtual ~ChangeStringCommand() = default;

	void Execute() override
	{
		prop_->Str = newValue_;

		auto parent = prop_->Parent.lock();

		if (parent != nullptr)
		{
			auto parentMaterial = parent->Parent.lock();

			if (parentMaterial != nullptr)
			{
				parentMaterial->MakeContentDirty(parent);
			}
		}
	}

	void Unexecute() override
	{
		prop_->Str = oldValue_;

		auto parent = prop_->Parent.lock();

		if (parent != nullptr)
		{
			auto parentMaterial = parent->Parent.lock();

			if (parentMaterial != nullptr)
			{
				parentMaterial->MakeContentDirty(parent);
			}
		}
	}

	bool Merge(ICommand* command)
	{

		if (command->GetTag() != this->GetTag())
			return false;

		auto command_ = static_cast<ChangeStringCommand*>(command);
		if (command_->prop_ != this->prop_)
			return false;

		this->oldValue_ = command_->oldValue_;

		return true;
	}

	virtual const char* GetTag() { return tag_changeStringCommand; }
};

class ChangeNodeRegionCommand : public ICommand
{
private:
	std::shared_ptr<Node> node_;
	std::array<Vector2DF,2> newValue_;
	std::array<Vector2DF,2> oldValue_;

public:
	ChangeNodeRegionCommand(std::shared_ptr<Node> node, std::array<Vector2DF,2> newValue, std::array<Vector2DF,2> oldValue)
		: node_(node), newValue_(newValue), oldValue_(oldValue)
	{
	}

	virtual ~ChangeNodeRegionCommand() {}

	void Execute() override
	{
		node_->Pos = newValue_[0];
		node_->CommentSize = newValue_[1];
		node_->MakePosDirtied();
	}

	void Unexecute() override
	{
		node_->Pos = oldValue_[0];
		node_->CommentSize = oldValue_[1];
		node_->MakePosDirtied();
	}

	bool Merge(ICommand* command)
	{

		if (command->GetTag() != this->GetTag())
			return false;

		auto command_ = static_cast<ChangeNodeRegionCommand*>(command);
		if (command_->node_ != this->node_)
			return false;

		this->oldValue_ = command_->oldValue_;

		return true;
	}

	virtual const char* GetTag() { return tag_changeNodePosCommand; }
};

class ChangeMultiNodePosCommand : public ICommand
{
private:
	std::vector<std::shared_ptr<Node>> targetNodes_;
	std::vector<Vector2DF> newValues_;
	std::vector<Vector2DF> oldValues_;

public:
	ChangeMultiNodePosCommand(std::vector<std::shared_ptr<Node>> nodes, std::vector<Vector2DF> newValues, std::vector<Vector2DF> oldValues)
		: targetNodes_(nodes), newValues_(newValues), oldValues_(oldValues)
	{
	}

	virtual ~ChangeMultiNodePosCommand() {}

	void Execute() override
	{
		for (size_t i = 0; i < targetNodes_.size(); i++)
		{
			targetNodes_[i]->Pos = newValues_[i];
			targetNodes_[i]->MakePosDirtied();
		}
	}

	void Unexecute() override
	{
		for (size_t i = 0; i < targetNodes_.size(); i++)
		{
			targetNodes_[i]->Pos = oldValues_[i];
			targetNodes_[i]->MakePosDirtied();
		}
	}

	bool Merge(ICommand* command)
	{

		if (command->GetTag() != this->GetTag())
			return false;

		auto command_ = static_cast<ChangeMultiNodePosCommand*>(command);
		if (this->targetNodes_.size() != command_->targetNodes_.size())
		{
			return false;
		}

		for (size_t i = 0; i < targetNodes_.size(); i++)
		{
			if (targetNodes_[i] != command_->targetNodes_[i])
				return false;
		}

		this->oldValues_ = command_->oldValues_;

		return true;
	}

	virtual const char* GetTag() { return tag_changeMultiNodePosCommand; }
};

int32_t Node::GetInputPinIndex(const std::string& name)
{

	for (size_t i = 0; i < InputPins.size(); i++)
	{
		if (Parameter->InputPins[i]->Name == name)
			return static_cast<int32_t>(i);
	}

	return -1;
}

int32_t Node::GetOutputPinIndex(const std::string& name)
{

	for (size_t i = 0; i < OutputPins.size(); i++)
	{
		if (Parameter->OutputPins[i]->Name == name)
			return static_cast<int32_t>(i);
	}

	return -1;
}

std::shared_ptr<NodeProperty> Node::GetProperty(const std::string& name) const
{
	auto index = Parameter->GetPropertyIndex(name);
	if (index < 0)
		return nullptr;
	return Properties[index];
}

void Node::UpdateRegion(const Vector2DF& pos, const Vector2DF& size)
{

	if (Pos.X == pos.X && Pos.Y == pos.Y && CommentSize.X == size.X && CommentSize.Y == size.Y)
		return;

	Pos = pos;

	auto value_old = std::array<Vector2DF, 2>{Pos, CommentSize};
	auto value_new = std::array<Vector2DF, 2>{pos, size};

	auto command = std::make_shared<ChangeNodeRegionCommand>(shared_from_this(), value_new, value_old);

	auto material = material_.lock();
	if (material != nullptr)
	{
		material->GetCommandManager()->Execute(command);
	}
}

uint64_t Material::GetIDAndNext()
{
	auto ret = nextGUID;
	nextGUID++;

	if (nextGUID > std::numeric_limits<uint64_t>::max() - 0xff)
	{
		nextGUID = 0xff;
	}

	return ret;
}

bool Material::FindLoop(std::shared_ptr<Pin> pin1, std::shared_ptr<Pin> pin2)
{
	auto inputPin = pin1;
	auto outputPin = pin2;

	if (inputPin->PinDirection == PinDirectionType::Output)
	{
		std::swap(inputPin, outputPin);
	}

	std::unordered_set<std::shared_ptr<Pin>> visited;
	visited.insert(outputPin);

	std::function<bool(std::weak_ptr<Node>)> visit;

	visit = [&](std::weak_ptr<Node> node) -> bool {
		auto locked_node = node.lock();

		for (auto p : locked_node->OutputPins)
		{
			if (p == outputPin)
				return true;

			if (visited.count(p) > 0)
				continue;

			visited.insert(p);

			auto connected_pins = GetConnectedPins(p);
			for (auto p2 : connected_pins)
			{
				if (visit(p2->Parent))
					return true;
			}
		}

		return false;
	};

	return visit(inputPin->Parent);
}

std::string Material::SaveAsStrInternal(std::vector<std::shared_ptr<Node>> nodes,
										std::vector<std::shared_ptr<Link>> links,
										const char* basePath,
										SaveLoadAimType aim)
{
	// calculate left pos
	Vector2DF upperLeftPos = Vector2DF(FLT_MAX, FLT_MAX);

	if (aim == SaveLoadAimType::CopyOrPaste)
	{
		for (auto node : nodes)
		{
			upperLeftPos.X = std::min(upperLeftPos.X, node->Pos.X);
			upperLeftPos.Y = std::min(upperLeftPos.Y, node->Pos.Y);
		}
	}
	else
	{
		upperLeftPos.X = 0.0f;
		upperLeftPos.Y = 0.0f;
	}

	picojson::object rootJson;
	picojson::array nodesJson;

	std::unordered_set<std::string> enabledTextures;

	rootJson.insert(std::make_pair("Project", picojson::value("EffekseerMaterial")));

	for (auto node : nodes)
	{
		picojson::object nodeJson;
		nodeJson.insert(std::make_pair("GUID", picojson::value((double)node->GUID)));
		nodeJson.insert(std::make_pair("Type", picojson::value(node->Parameter->TypeName.c_str())));
		nodeJson.insert(std::make_pair("PosX", picojson::value(node->Pos.X - upperLeftPos.X)));
		nodeJson.insert(std::make_pair("PosY", picojson::value(node->Pos.Y - upperLeftPos.Y)));
		nodeJson.insert(std::make_pair("IsPreviewOpened", picojson::value(node->IsPreviewOpened)));

		if (node->Parameter->Type == NodeType::Comment)
		{
			nodeJson.insert(std::make_pair("CommentSizeX", picojson::value(node->CommentSize.X)));
			nodeJson.insert(std::make_pair("CommentSizeY", picojson::value(node->CommentSize.Y)));
		}

		picojson::array descsJson;

		if (node->Parameter->IsDescriptionExported)
		{
			for (size_t i = 0; i < node->Descriptions.size(); i++)
			{
				picojson::object descJson;
				descJson.insert(std::make_pair("Summary", picojson::value(node->Descriptions[i]->Summary)));
				descJson.insert(std::make_pair("Detail", picojson::value(node->Descriptions[i]->Detail)));
				descsJson.push_back(picojson::value(descJson));
			}
		}

		picojson::array propsJson;

		for (size_t i = 0; i < node->Parameter->Properties.size(); i++)
		{
			picojson::object prop_;

			auto pp = node->Parameter->Properties[i];
			auto p = node->Properties[i];

			if (pp->Type == ValueType::Float1)
			{
				prop_.insert(std::make_pair("Value1", picojson::value((double)p->Floats[0])));
			}
			else if (pp->Type == ValueType::Float2)
			{
				prop_.insert(std::make_pair("Value1", picojson::value((double)p->Floats[0])));
				prop_.insert(std::make_pair("Value2", picojson::value((double)p->Floats[1])));
			}
			else if (pp->Type == ValueType::Float3)
			{
				prop_.insert(std::make_pair("Value1", picojson::value((double)p->Floats[0])));
				prop_.insert(std::make_pair("Value2", picojson::value((double)p->Floats[1])));
				prop_.insert(std::make_pair("Value3", picojson::value((double)p->Floats[2])));
			}
			else if (pp->Type == ValueType::Float4)
			{
				prop_.insert(std::make_pair("Value1", picojson::value((double)p->Floats[0])));
				prop_.insert(std::make_pair("Value2", picojson::value((double)p->Floats[1])));
				prop_.insert(std::make_pair("Value3", picojson::value((double)p->Floats[2])));
				prop_.insert(std::make_pair("Value4", picojson::value((double)p->Floats[3])));
			}
			else if (pp->Type == ValueType::Bool)
			{
				prop_.insert(std::make_pair("Value", picojson::value(p->Floats[0] > 0)));
			}
			else if (pp->Type == ValueType::String)
			{
				prop_.insert(std::make_pair("Value", picojson::value(p->Str)));
			}
			else if (pp->Type == ValueType::Int)
			{
				prop_.insert(std::make_pair("Value", picojson::value((double)p->Floats[0])));
			}
			else if (pp->Type == ValueType::Texture)
			{
				auto absStr = p->Str;

				if (aim == SaveLoadAimType::CopyOrPaste)
				{
					prop_.insert(std::make_pair("Value", picojson::value(absStr)));
					enabledTextures.insert(absStr);
				}
				else
				{
					auto relative = PathHelper::Relative(absStr, std::string(basePath));
					prop_.insert(std::make_pair("Value", picojson::value(relative)));
					enabledTextures.insert(relative);
				}
			}
			else if (pp->Type == ValueType::Enum)
			{
				prop_.insert(std::make_pair("Value", picojson::value((double)p->Floats[0])));
			}
			else
			{
				assert(0);
			}

			propsJson.push_back(picojson::value(prop_));
		}

		nodeJson.insert(std::make_pair("Props", picojson::value(propsJson)));

		if (node->Descriptions.size() > 0 && node->Parameter->IsDescriptionExported)
		{
			nodeJson.insert(std::make_pair("Descs", picojson::value(descsJson)));
		}

		nodesJson.push_back(picojson::value(nodeJson));
	}

	rootJson.insert(std::make_pair("Nodes", picojson::value(nodesJson)));

	picojson::array linksJson;

	for (auto link : links)
	{
		picojson::object linkJson;
		linkJson.insert(std::make_pair("GUID", picojson::value((double)link->GUID)));

		auto inputNode = link->InputPin->Parent.lock();
		auto inputName = inputNode->Parameter->InputPins[link->InputPin->PinIndex]->Name;

		auto outputNode = link->OutputPin->Parent.lock();
		auto outputName = outputNode->Parameter->OutputPins[link->OutputPin->PinIndex]->Name;

		linkJson.insert(std::make_pair("InputGUID", picojson::value((double)link->InputPin->Parent.lock()->GUID)));
		linkJson.insert(std::make_pair("InputPin", picojson::value(inputName)));
		linkJson.insert(std::make_pair("OutputGUID", picojson::value((double)link->OutputPin->Parent.lock()->GUID)));
		linkJson.insert(std::make_pair("OutputPin", picojson::value(outputName)));

		linksJson.push_back(picojson::value(linkJson));
	}

	rootJson.insert(std::make_pair("Links", picojson::value(linksJson)));

	if (aim == SaveLoadAimType::IO)
	{
		picojson::array customdata;

		for (size_t i = 0; i < CustomData.size(); i++)
		{
			picojson::object cd;
			cd.insert(std::make_pair("Value1", picojson::value(CustomData[i].Values[0])));
			cd.insert(std::make_pair("Value2", picojson::value(CustomData[i].Values[1])));
			cd.insert(std::make_pair("Value3", picojson::value(CustomData[i].Values[2])));
			cd.insert(std::make_pair("Value4", picojson::value(CustomData[i].Values[3])));
			customdata.push_back(picojson::value(cd));
		}

		rootJson.insert(std::make_pair("CustomData", picojson::value(customdata)));

		picojson::array customdata_desc;

		for (size_t i = 0; i < CustomData.size(); i++)
		{
			picojson::array customdata_lang;

			for (size_t j = 0; j < CustomData[i].Descriptions.size(); j++)
			{
				picojson::object cd;
				cd.insert(std::make_pair("Summary", picojson::value(CustomData[i].Descriptions[j]->Summary)));
				cd.insert(std::make_pair("Detail", picojson::value(CustomData[i].Descriptions[j]->Detail)));
				customdata_lang.push_back(picojson::value(cd));
			}

			customdata_desc.push_back(picojson::value(customdata_lang));
		}

		rootJson.insert(std::make_pair("CustomDataDescs", picojson::value(customdata_desc)));
	}

	if (aim == SaveLoadAimType::IO)
	{
		picojson::array textures_;

		for (auto texture : textures)
		{
			picojson::object texture_;

			auto absStr = texture.second->Path;
			auto relative = PathHelper::Relative(absStr, std::string(basePath));

			if (enabledTextures.find(relative) == enabledTextures.end())
			{
				continue;
			}

			texture_.insert(std::make_pair("Path", picojson::value(relative)));
			texture_.insert(std::make_pair("Type", picojson::value(static_cast<double>(texture.second->Type))));

			textures_.push_back(picojson::value(texture_));
		}

		rootJson.insert(std::make_pair("Textures", picojson::value(textures_)));
	}

	auto str_main = picojson::value(rootJson).serialize();

	return str_main;
}

void Material::LoadFromStrInternal(
	const char* json, Vector2DF offset, std::shared_ptr<Library> library, const char* basePath, SaveLoadAimType aim)
{
	// offset must be int
	offset.X = std::floor(offset.X);
	offset.Y = std::floor(offset.Y);

	picojson::value root_;
	auto err = picojson::parse(root_, json);
	if (!err.empty())
	{
		std::cerr << err << std::endl;
		return;
	}

	// check project
	picojson::value project_name_obj = root_.get("Project");
	auto project_name = project_name_obj.get<std::string>();
	if (project_name != "EffekseerMaterial")
		return;

	picojson::value nodes_obj = root_.get("Nodes");
	picojson::value links_obj = root_.get("Links");

	picojson::array nodes_json = nodes_obj.get<picojson::array>();
	picojson::array linksJson = links_obj.get<picojson::array>();

	// reset id
	if (aim == SaveLoadAimType::IO)
	{
		uint64_t guidMax = 0;
		for (auto node_ : nodes_json)
		{
			auto guid_obj = node_.get("GUID");
			auto guid = (uint64_t)guid_obj.get<double>();

			guidMax = std::max(guidMax, guid);
		}

		if (guidMax > 255)
		{
			nextGUID = guidMax + 1;
		}
	}

	std::map<uint64_t, uint64_t> oldIDToNewID;

	for (auto node_ : nodes_json)
	{
		auto guid_obj = node_.get("GUID");
		auto guid = (uint64_t)guid_obj.get<double>();

		auto type_obj = node_.get("Type");
		auto type = type_obj.get<std::string>();

		auto node_library = library->FindContentWithTypeName(type.c_str());
		if (node_library == nullptr)
			continue;

		auto node_parameter = node_library->Create();

		auto guidNew = guid;
		if (aim == SaveLoadAimType::CopyOrPaste)
		{
			guidNew = 0;
		}

		std::shared_ptr<Node> node = CreateNode(node_parameter, false, guidNew);

		auto pos_x_obj = node_.get("PosX");
		node->Pos.X = (float)pos_x_obj.get<double>() + offset.X;

		auto pos_y_obj = node_.get("PosY");
		node->Pos.Y = (float)pos_y_obj.get<double>() + offset.Y;

		auto is_preview_opened_obj = node_.get("IsPreviewOpened");
		if (is_preview_opened_obj.is<bool>())
		{
			node->IsPreviewOpened = is_preview_opened_obj.get<bool>();
		}

		if (node->Parameter->Type == NodeType::Comment)
		{
			auto comment_size_x_obj = node_.get("CommentSizeX");
			if (comment_size_x_obj.is<double>())
			{
				node->CommentSize.X = (float)comment_size_x_obj.get<double>();
			}

			auto comment_size_y_obj = node_.get("CommentSizeY");
			if (comment_size_y_obj.is<double>())
			{
				node->CommentSize.Y = (float)comment_size_y_obj.get<double>();
			}
		}

		oldIDToNewID[guid] = node->GUID;
		// node->GUID = guid; // OK?

		if (node_.contains("Descs"))
		{
			auto descs_obj = node_.get("Descs");
			auto descs_ = descs_obj.get<picojson::array>();

			for (int32_t i = 0; i < descs_.size(); i++)
			{
				node->Descriptions[i] = std::make_shared<NodeDescription>();
				node->Descriptions[i]->Summary = descs_[i].get("Summary").get<std::string>();
				node->Descriptions[i]->Detail = descs_[i].get("Detail").get<std::string>();
			}
		}

		auto props_obj = node_.get("Props");
		auto props_ = props_obj.get<picojson::array>();

		for (int32_t i = 0; i < props_.size(); i++)
		{
			if (node->Parameter->Properties[i]->Type == ValueType::Float1)
			{
				node->Properties[i]->Floats[0] = static_cast<float>(props_[i].get("Value1").get<double>());
			}
			else if (node->Parameter->Properties[i]->Type == ValueType::Float2)
			{
				node->Properties[i]->Floats[0] = static_cast<float>(props_[i].get("Value1").get<double>());
				node->Properties[i]->Floats[1] = static_cast<float>(props_[i].get("Value2").get<double>());
			}
			else if (node->Parameter->Properties[i]->Type == ValueType::Float3)
			{
				node->Properties[i]->Floats[0] = static_cast<float>(props_[i].get("Value1").get<double>());
				node->Properties[i]->Floats[1] = static_cast<float>(props_[i].get("Value2").get<double>());
				node->Properties[i]->Floats[2] = static_cast<float>(props_[i].get("Value3").get<double>());
			}
			else if (node->Parameter->Properties[i]->Type == ValueType::Float4)
			{
				node->Properties[i]->Floats[0] = static_cast<float>(props_[i].get("Value1").get<double>());
				node->Properties[i]->Floats[1] = static_cast<float>(props_[i].get("Value2").get<double>());
				node->Properties[i]->Floats[2] = static_cast<float>(props_[i].get("Value3").get<double>());
				node->Properties[i]->Floats[3] = static_cast<float>(props_[i].get("Value4").get<double>());
			}
			else if (node->Parameter->Properties[i]->Type == ValueType::Bool)
			{
				node->Properties[i]->Floats[0] = props_[i].get("Value").get<bool>() ? 1.0f : 0.0f;
			}
			else if (node->Parameter->Properties[i]->Type == ValueType::String)
			{
				auto str = props_[i].get("Value").get<std::string>();
				node->Properties[i]->Str = str;
			}
			else if (node->Parameter->Properties[i]->Type == ValueType::Int)
			{
				node->Properties[i]->Floats[0] = static_cast<float>(props_[i].get("Value").get<double>());
			}
			else if (node->Parameter->Properties[i]->Type == ValueType::Texture)
			{
				auto str = props_[i].get("Value").get<std::string>();

				if (aim == SaveLoadAimType::CopyOrPaste)
				{
					node->Properties[i]->Str = str;
				}
				else
				{
					auto absolute = PathHelper::Absolute(str, std::string(basePath));
					node->Properties[i]->Str = absolute;
				}
			}
			else if (node->Parameter->Properties[i]->Type == ValueType::Enum)
			{
				node->Properties[i]->Floats[0] = static_cast<float>(props_[i].get("Value").get<double>());
			}
			else
			{
				assert(0);
			}
		}
	}

	for (auto link_ : linksJson)
	{
		auto guid_obj = link_.get("GUID");
		auto guid = (uint64_t)guid_obj.get<double>();

		auto InputGUID_obj = link_.get("InputGUID");
		auto InputGUID = (uint64_t)InputGUID_obj.get<double>();

		auto InputPin_obj = link_.get("InputPin");
		auto InputPin = InputPin_obj.get<std::string>();

		auto OutputGUID_obj = link_.get("OutputGUID");
		auto OutputGUID = (uint64_t)OutputGUID_obj.get<double>();

		auto OutputPin_obj = link_.get("OutputPin");
		auto OutputPin = OutputPin_obj.get<std::string>();

		auto inputNode = FindNode(oldIDToNewID[InputGUID]);
		auto outputNode = FindNode(oldIDToNewID[OutputGUID]);

		// Compatibility (TODO : refactor)
		if (outputNode->Parameter->TypeName == "SampleTexture")
		{
			if (OutputPin == "Output")
			{
				OutputPin = "RGBA";
			}
		}

		auto InputPinIndex = inputNode->GetInputPinIndex(InputPin);
		auto OutputPinIndex = outputNode->GetOutputPinIndex(OutputPin);

		if (InputPinIndex >= 0 && OutputPinIndex >= 0)
		{
			ConnectPin(inputNode->InputPins[InputPinIndex], outputNode->OutputPins[OutputPinIndex]);
		}
	}

	if (aim == SaveLoadAimType::IO)
	{
		picojson::value customdata_obj = root_.get("CustomData");
		if (customdata_obj.is<picojson::array>())
		{
			picojson::array customdata = customdata_obj.get<picojson::array>();

			for (int i = 0; i < 2; i++)
			{
				CustomData[i].Values[0] = static_cast<float>(customdata[i].get("Value1").get<double>());
				CustomData[i].Values[1] = static_cast<float>(customdata[i].get("Value2").get<double>());
				CustomData[i].Values[2] = static_cast<float>(customdata[i].get("Value3").get<double>());
				CustomData[i].Values[3] = static_cast<float>(customdata[i].get("Value4").get<double>());
			}
		}

		picojson::value customdata_desc_obj = root_.get("CustomDataDescs");
		if (customdata_desc_obj.is<picojson::array>())
		{
			picojson::array customdata = customdata_desc_obj.get<picojson::array>();

			for (int n = 0; n < 2; n++)
			{
				if (customdata[n].is<picojson::array>())
				{
					picojson::array descs_ = customdata[n].get<picojson::array>();
					for (int32_t i = 0; i < descs_.size(); i++)
					{

						CustomData[n].Descriptions[i] = std::make_shared<NodeDescription>();
						CustomData[n].Descriptions[i]->Summary = descs_[i].get("Summary").get<std::string>();
						CustomData[n].Descriptions[i]->Detail = descs_[i].get("Detail").get<std::string>();
					}
				}
			}
		}

		for (auto node : nodes_)
		{
			if (node->Parameter->Type == NodeType::CustomData1)
			{
				node->Descriptions = this->CustomData[0].Descriptions;
			}

			if (node->Parameter->Type == NodeType::CustomData2)
			{
				node->Descriptions = this->CustomData[1].Descriptions;
			}
		}
	}

	if (aim == SaveLoadAimType::IO)
	{
		picojson::value textures_obj = root_.get("Textures");

		if (textures_obj.is<picojson::array>())
		{
			picojson::array textures_ = textures_obj.get<picojson::array>();

			for (auto texture_ : textures_)
			{
				auto path_obj = texture_.get("Path");
				auto path = path_obj.get<std::string>();
				auto absolute = PathHelper::Absolute(path, std::string(basePath));

				auto textureType_obj = texture_.get("Type");
				auto textureType = textureType_obj.get<double>();

				auto texture = std::make_shared<TextureInfo>();
				texture->Path = absolute;
				texture->Type = static_cast<TextureValueType>(static_cast<int>(textureType));
				textures[absolute] = texture;
			}
		}
	}
}

Material::Material() { commandManager_ = std::make_shared<CommandManager>(); }

Material::~Material() {}

const std::string& Material::GetPath() const { return path_; }

void Material::SetPath(const std::string& path) { path_ = path; }

void Material::Initialize()
{
	auto outputNodeParam = std::make_shared<NodeOutput>();
	auto outputNode = CreateNode(outputNodeParam, true);
	outputNode->UpdateRegion(Vector2DF(200, 100), Vector2DF{});

	for (size_t ci = 0; ci < CustomData.size(); ci++)
	{
		CustomData[ci].Descriptions.resize(static_cast<int32_t>(LanguageType::Max));

		for (size_t i = 0; i < CustomData[ci].Descriptions.size(); i++)
		{
			CustomData[ci].Descriptions[i] = std::make_shared<NodeDescription>();
		}
	}

	commandManager_->Reset();
}

std::vector<std::shared_ptr<Pin>> Material::GetConnectedPins(std::shared_ptr<Pin> pin)
{
	std::vector<std::shared_ptr<Pin>> ret;

	if (pin->PinDirection == PinDirectionType::Input)
	{
		for (auto link : links_)
		{
			if (link->InputPin == pin)
			{
				ret.push_back(link->OutputPin);
			}
		}
	}
	else
	{
		for (auto link : links_)
		{
			if (link->OutputPin == pin)
			{
				ret.push_back(link->InputPin);
			}
		}
	}

	return ret;
}

std::unordered_set<std::shared_ptr<Pin>> Material::GetRelatedPins(std::shared_ptr<Pin> pin)
{
	std::unordered_set<std::shared_ptr<Pin>> ret;

	auto pins = GetConnectedPins(pin);

	ret.insert(pins.begin(), pins.end());

	for (auto p : pins)
	{
		auto n = p->Parent.lock();
		if (n != nullptr)
		{
			if (p->PinDirection == PinDirectionType::Input)
			{
				for (auto pp : n->OutputPins)
				{
					if (ret.find(pp) != ret.end())
					{
						auto ppins = GetRelatedPins(pp);					
						ret.insert(ppins.begin(), ppins.end());
					}
				}
			}
			else if (p->PinDirection == PinDirectionType::Output)
			{
				for (auto pp : n->InputPins)
				{
					if (ret.find(pp) != ret.end())
					{
						auto ppins = GetRelatedPins(pp);
						ret.insert(ppins.begin(), ppins.end());
					}
				}
			}
		}
	}

	return ret;
}

ValueType Material::GetPinType(DefaultType type)
{
	if (type == DefaultType::UV)
		return ValueType::Float2;
	return ValueType::Float1;
}

ValueType Material::GetDesiredPinType(std::shared_ptr<Pin> pin, std::unordered_set<std::shared_ptr<Pin>>& visited)
{
	if (pin->Parameter->Type != ValueType::FloatN)
		return pin->Parameter->Type;

	if (visited.count(pin) != 0)
		return ValueType::Unknown;
	visited.insert(pin);

	// self node
	auto selfNode = pin->Parent;

	if (pin->PinDirection == PinDirectionType::Output)
	{
		std::vector<ValueType> inputTypes;

		for (int i = 0; i < selfNode.lock()->InputPins.size(); i++)
		{
			auto type = GetDesiredPinType(selfNode.lock()->InputPins[i], visited);
			inputTypes.push_back(type);
		}

		auto type = selfNode.lock()->Parameter->GetOutputType(shared_from_this(), selfNode.lock(), inputTypes);

		if (type != ValueType::Unknown && type != ValueType::FloatN)
			return type;
	}

	if (pin->PinDirection == PinDirectionType::Input)
	{
		auto relatedPins = GetConnectedPins(pin);

		for (auto relatedPin : relatedPins)
		{
			if (visited.count(relatedPin) == 0)
			{
				auto type = GetDesiredPinType(relatedPin, visited);
				if (type != ValueType::Unknown && type != ValueType::FloatN)
					return type;
			}
		}
	}

	return GetPinType(pin->Parameter->Default);
}

std::shared_ptr<Node> Material::CreateNode(std::shared_ptr<NodeParameter> parameter, bool isDirectly, uint64_t guid)
{
	auto node = std::make_shared<Node>();
	node->material_ = this->shared_from_this();
	node->Parameter = parameter;

	if (parameter->Type == NodeType::Comment)
	{
		node->CommentSize = Vector2DF{
			100.0f, 100.0f};
	}

	if (guid > 0)
	{
		node->GUID = guid;
	}
	else
	{
		node->GUID = GetIDAndNext();
	}

	node->IsPreviewOpened = parameter->IsPreviewOpened;

	if (parameter->HasDescription)
	{
		if (parameter->Type == NodeType::CustomData1)
		{
			node->Descriptions = this->CustomData[0].Descriptions;
		}
		else if (parameter->Type == NodeType::CustomData2)
		{
			node->Descriptions = this->CustomData[1].Descriptions;
		}
		else
		{
			node->Descriptions.resize(static_cast<int32_t>(LanguageType::Max));

			for (size_t i = 0; i < node->Descriptions.size(); i++)
			{
				node->Descriptions[i] = std::make_shared<NodeDescription>();
			}
		}
	}

	for (auto i = 0; i < parameter->InputPins.size(); i++)
	{
		auto pp = parameter->InputPins[i];

		auto p = std::make_shared<Pin>();
		p->Parameter = pp;
		p->Parent = node;
		p->PinDirection = PinDirectionType::Input;
		p->PinIndex = i;
		p->GUID = GetIDAndNext();

		node->InputPins.push_back(p);
	}

	for (auto i = 0; i < parameter->OutputPins.size(); i++)
	{
		auto pp = parameter->OutputPins[i];

		auto p = std::make_shared<Pin>();
		p->Parameter = pp;
		p->Parent = node;
		p->PinDirection = PinDirectionType::Output;
		p->PinIndex = i;
		p->GUID = GetIDAndNext();

		node->OutputPins.push_back(p);
	}

	for (auto i = 0; i < parameter->Properties.size(); i++)
	{
		auto np = std::make_shared<NodeProperty>();
		np->Floats = parameter->Properties[i]->DefaultValues;
		np->Str = parameter->Properties[i]->DefaultStr;
		np->Parent = node;

		node->Properties.push_back(np);
	}

	node->Parent = shared_from_this();

	auto val_old = nodes_;
	auto val_new = nodes_;
	val_new.push_back(node);

	if (isDirectly)
	{
		this->nodes_ = val_new;
	}
	else
	{
		auto command = std::make_shared<DelegateCommand>(
			[this, val_new]() -> void {
				this->nodes_ = val_new;
				this->UpdateWarnings();
			},
			[this, val_old]() -> void {
				this->nodes_ = val_old;
				this->UpdateWarnings();
			});

		commandManager_->Execute(command);
	}

	return node;
}

void Material::RemoveNode(std::shared_ptr<Node> node)
{
	auto nodes_old = nodes_;
	auto links_old = links_;

	auto nodes_new = nodes_;
	auto links_new = links_;

	nodes_new.erase(std::remove(nodes_new.begin(), nodes_new.end(), node), nodes_new.end());

	std::vector<std::shared_ptr<Link>> removing;
	for (auto link : links_new)
	{
		auto beginNode = link->InputPin->Parent.lock();
		auto endNode = link->OutputPin->Parent.lock();

		if (beginNode == nullptr || beginNode == node || endNode == nullptr || endNode == node)
		{
			removing.push_back(link);
		}
	}

	for (auto link : removing)
	{
		links_new.erase(std::remove(links_new.begin(), links_new.end(), link), links_new.end());
	}

	auto command = std::make_shared<DelegateCommand>(
		[this, nodes_new, links_new]() -> void {
			this->nodes_ = nodes_new;
			this->links_ = links_new;
			this->UpdateWarnings();
		},
		[this, nodes_old, links_old]() -> void {
			this->nodes_ = nodes_old;
			this->links_ = links_old;
			this->UpdateWarnings();
		});

	commandManager_->Execute(command);
}

ConnectResultType Material::CanConnectPin(std::shared_ptr<Pin> pin1, std::shared_ptr<Pin> pin2)
{
	if (pin1 == pin2)
		return ConnectResultType::SamePin;
	if (pin1->PinDirection == pin2->PinDirection)
		return ConnectResultType::SameDirection;
	if (pin1->Parent.lock() == pin2->Parent.lock())
		return ConnectResultType::SameNode;

	std::unordered_set<std::shared_ptr<Pin>> visited1;
	std::unordered_set<std::shared_ptr<Pin>> visited2;
	auto pin1Type = GetDesiredPinType(pin1, visited1);
	auto pin2Type = GetDesiredPinType(pin2, visited2);

	// All type can be connected in this version.
	if (pin1Type != pin2Type)
	{
		if (IsFloatValueType(pin1Type) && IsFloatValueType(pin2Type))
		{
			// OK
		}
		// else if (pin1->Parameter->Type == ValueType::FloatN && IsFloatValueType(pin2Type))
		//{
		//	// OK
		//}
		else
		{
			return ConnectResultType::Type;
		}
	}

	// Loop has been detected
	if (FindLoop(pin1, pin2))
	{
		return ConnectResultType::Loop;
	}

	return ConnectResultType::OK;
}

ConnectResultType Material::ConnectPin(std::shared_ptr<Pin> pin1, std::shared_ptr<Pin> pin2)
{
	if (pin1 == pin2)
		return ConnectResultType::SamePin;
	if (pin1->PinDirection == pin2->PinDirection)
		return ConnectResultType::SameDirection;
	if (pin1->Parent.lock() == pin2->Parent.lock())
		return ConnectResultType::SameNode;

	std::unordered_set<std::shared_ptr<Pin>> visited1;
	std::unordered_set<std::shared_ptr<Pin>> visited2;
	auto pin1Type = GetDesiredPinType(pin1, visited1);
	auto pin2Type = GetDesiredPinType(pin2, visited2);

	// All type can be connected in this version.
	if (pin1Type != pin2Type)
	{
		if (IsFloatValueType(pin1Type) && IsFloatValueType(pin2Type))
		{
			// OK
		}
		// else if (pin1->Parameter->Type == ValueType::FloatN && IsFloatValueType(pin2Type))
		//{
		//	// OK
		//}
		else
		{
			return ConnectResultType::Type;
		}
	}

	// Loop has been detected
	if (FindLoop(pin1, pin2))
	{
		return ConnectResultType::Loop;
	}

	auto p1 = pin1;
	auto p2 = pin2;

	if (p1->PinDirection == PinDirectionType::Output)
	{
		std::swap(p1, p2);
	}

	auto links_old = links_;

	// Find multiple connect
	std::shared_ptr<Link> removingLink;
	for (auto link : links_)
	{
		if (link->InputPin == p1)
		{
			removingLink = link;
			break;
		}
	}

	if (removingLink != nullptr)
	{
		BreakPin(removingLink);
	}

	auto links_new = links_;

	auto link = std::make_shared<Link>();
	link->InputPin = p1;
	link->OutputPin = p2;
	link->GUID = GetIDAndNext();

	links_new.push_back(link);

	auto command = std::make_shared<DelegateCommand>(
		[this, links_new, p1]() -> void {
			this->links_ = links_new;
			this->UpdateWarnings();
			this->MakeDirty(p1->Parent.lock());
		},
		[this, links_old, p1]() -> void {
			this->links_ = links_old;
			this->UpdateWarnings();
			this->MakeDirty(p1->Parent.lock());
		});

	commandManager_->Execute(command);

	return ConnectResultType::OK;
}

bool Material::BreakPin(std::shared_ptr<Link> link)
{
	auto links_old = links_;
	auto links_new = links_;

	links_new.erase(std::remove(links_new.begin(), links_new.end(), link), links_new.end());

	auto inputNode = link->InputPin->Parent.lock();

	auto command = std::make_shared<DelegateCommand>(
		[this, links_new, inputNode]() -> void {
			this->links_ = links_new;
			this->UpdateWarnings();
			if (inputNode != nullptr)
			{
				MakeDirty(inputNode);
			}
		},
		[this, links_old, inputNode]() -> void {
			this->links_ = links_old;
			this->UpdateWarnings();
			if (inputNode != nullptr)
			{
				MakeDirty(inputNode);
			}
		});

	commandManager_->Execute(command);

	return true;
}

const std::vector<std::shared_ptr<Node>>& Material::GetNodes() const { return nodes_; }

const std::vector<std::shared_ptr<Link>>& Material::GetLinks() const { return links_; }

const std::map<std::string, std::shared_ptr<TextureInfo>> Material::GetTextures() const { return textures; }

std::shared_ptr<Node> Material::FindNode(uint64_t guid)
{
	for (auto node : nodes_)
	{
		if (node->GUID == guid)
			return node;
	}
	return nullptr;
}

std::shared_ptr<Link> Material::FindLink(uint64_t guid)
{
	for (auto link : links_)
	{
		if (link->GUID == guid)
			return link;
	}
	return nullptr;
}

std::shared_ptr<Pin> Material::FindPin(uint64_t guid)
{
	for (auto node : nodes_)
	{
		for (auto pin : node->InputPins)
		{
			if (pin->GUID == guid)
				return pin;
		}

		for (auto pin : node->OutputPins)
		{
			if (pin->GUID == guid)
				return pin;
		}
	}

	return nullptr;
}

std::shared_ptr<TextureInfo> Material::FindTexture(const char* path)
{

	auto key = std::string(path);

	auto kv = textures.find(path);

	if (kv != textures.end())
	{
		return kv->second;
	}

	auto texture = std::make_shared<TextureInfo>();

	texture->Type = TextureValueType::Color;
	texture->Path = path;
	textures[key] = texture;

	return texture;
}

std::string Material::Copy(std::vector<std::shared_ptr<Node>> nodes, const char* basePath)
{
	std::unordered_set<std::shared_ptr<Node>> setNodes;

	for (auto node : nodes)
	{
		setNodes.insert(node);
	}

	std::unordered_set<std::shared_ptr<Link>> collectedLinks;

	for (auto node : nodes)
	{
		for (auto link : links_)
		{
			auto input = link->InputPin->Parent.lock();
			auto output = link->OutputPin->Parent.lock();

			if (setNodes.find(input) != setNodes.end() && setNodes.find(output) != setNodes.end())
			{
				collectedLinks.insert(link);
			}
		}
	}

	std::vector<std::shared_ptr<Link>> links;
	for (auto link : collectedLinks)
	{
		links.push_back(link);
	}

	return SaveAsStrInternal(nodes, links, basePath, SaveLoadAimType::CopyOrPaste);
}

void Material::Paste(std::string content, const Vector2DF& pos, std::shared_ptr<Library> library, const char* basePath)
{
	commandManager_->StartCollection();

	LoadFromStrInternal(content.c_str(), pos, library, basePath, SaveLoadAimType::CopyOrPaste);

	commandManager_->EndCollection();
}

void Material::ApplyMoveNodesMultiply(std::vector<std::shared_ptr<Node>> nodes, std::vector<Vector2DF>& poses)
{

	assert(nodes.size() == poses.size());

	if (nodes.size() == 0)
		return;

	bool same = true;
	for (size_t i = 0; i < nodes.size(); i++)
	{
		if (nodes[i]->Pos.X != poses[i].X || nodes[i]->Pos.Y != poses[i].Y)
		{
			same = false;
		}
	}

	if (same)
		return;

	std::vector<Vector2DF> olds;
	for (size_t i = 0; i < nodes.size(); i++)
	{
		olds.push_back(nodes[i]->Pos);
	}

	auto command = std::make_shared<ChangeMultiNodePosCommand>(nodes, poses, olds);

	commandManager_->Execute(command);
}

void Material::ChangeValue(std::shared_ptr<NodeProperty> prop, std::array<float, 4> value)
{
	auto value_old = prop->Floats;
	auto value_new = value;

	auto command = std::make_shared<ChangeNumberCommand>(prop, value_new, value_old);

	commandManager_->Execute(command);
}

void Material::ChangeValue(std::shared_ptr<NodeProperty> prop, std::string value)
{
	auto value_old = prop->Str;
	auto value_new = value;

	auto command = std::make_shared<ChangeStringCommand>(prop, value_new, value_old);
	commandManager_->Execute(command);
}

void Material::ChangeValueTextureType(std::shared_ptr<TextureInfo> prop, TextureValueType type)
{
	auto value_old = prop->Type;
	auto value_new = type;

	auto command = std::make_shared<DelegateCommand>(
		[prop, value_new, this]() -> void {
			prop->Type = value_new;
			// TODO make content dirty
		},
		[prop, value_old, this]() -> void {
			prop->Type = value_old;
			// TODO make content dirty
		});

	commandManager_->Execute(command);
}

void Material::MakeDirty(std::shared_ptr<Node> node, bool doesUpdateWarnings)
{
	node->isDirtied = true;

	for (auto o : node->OutputPins)
	{
		auto connected = GetConnectedPins(o);

		for (auto c : connected)
		{
			MakeDirty(c->Parent.lock(), false);
		}
	}

	if (doesUpdateWarnings)
	{
		UpdateWarnings();
	}
}

void Material::ClearDirty(std::shared_ptr<Node> node) { node->isDirtied = false; }

void Material::MakeContentDirty(std::shared_ptr<Node> node)
{
	node->isContentDirtied = true;

	for (auto o : node->OutputPins)
	{
		auto connected = GetConnectedPins(o);

		for (auto c : connected)
		{
			MakeContentDirty(c->Parent.lock());
		}
	}

	UpdateWarnings();
}

void Material::ClearContentDirty(std::shared_ptr<Node> node) { node->isContentDirtied = false; }

void Material::UpdateWarnings()
{
	for (auto& node : nodes_)
	{
		bool found = false;
		for (auto component : node->Parameter->BehaviorComponents)
		{
			if (component->IsGetWarningInherited)
			{
				node->CurrentWarning = component->GetWarning(this->shared_from_this(), node);
				found = true;
				break;
			}
		}

		if (!found)
		{
			node->CurrentWarning = node->Parameter->GetWarning(this->shared_from_this(), node);
		}
	}
}

void Material::LoadFromStr(const char* json, std::shared_ptr<Library> library, const char* basePath)
{
	// TODO check valid

	nodes_.clear();
	links_.clear();
	textures.clear();

	LoadFromStrInternal(json, Vector2DF(), library, basePath, SaveLoadAimType::IO);

	commandManager_->Reset();
}

std::string Material::SaveAsStr(const char* basePath) { return SaveAsStrInternal(nodes_, links_, basePath, SaveLoadAimType::IO); }

ErrorCode Material::Load(std::vector<uint8_t>& data, std::shared_ptr<Library> library, const char* basePath)
{

	int offset = 0;

	// header
	char prefix[5];

	memcpy(prefix, data.data() + offset, 4);
	offset += sizeof(int);

	prefix[4] = 0;

	if (std::string("EFKM") != std::string(prefix))
		return ErrorCode::InvalidFile;

	int version = 0;
	memcpy(&version, data.data() + offset, 4);
	offset += sizeof(int);

	if (version > lastestSupportedVersion_)
	{
		return ErrorCode::NewVersion;
	}

	uint64_t guid = 0;
	memcpy(&guid, data.data() + offset, 8);
	offset += sizeof(uint64_t);

	while (offset < data.size())
	{
		char chunk[5];
		memcpy(chunk, data.data() + offset, 4);
		offset += sizeof(int);
		chunk[4] = 0;

		int chunk_size = 0;
		memcpy(&chunk_size, data.data() + offset, 4);
		offset += sizeof(int);

		if (std::string("DATA") == std::string(chunk))
		{
			LoadFromStr((const char*)(data.data() + offset), library, basePath);
		}

		offset += chunk_size;
	}

	return ErrorCode::OK;
}

bool Material::Save(std::vector<uint8_t>& data, const char* basePath)
{
	// header

	const char* prefix = "EFKM";
	int version = MaterialVersion16;

	size_t offset = 0;

	offset = data.size();
	data.resize(data.size() + 4);
	memcpy(data.data() + offset, prefix, 4);

	offset = data.size();
	data.resize(data.size() + 4);
	memcpy(data.data() + offset, &version, 4);

	auto internalJson = SaveAsStr(basePath);
	auto hash_str = std::hash<std::string>();
	auto guid = (uint64_t)hash_str(internalJson);

	offset = data.size();
	data.resize(data.size() + sizeof(uint64_t));
	memcpy(data.data() + offset, &guid, sizeof(uint64_t));

	// find output node
	std::shared_ptr<Node> outputNode;
	for (auto node : nodes_)
	{
		if (node->Parameter->Type == NodeType::Output)
		{
			outputNode = node;
		}
	}

	if (outputNode == nullptr)
	{
		assert(0);
		return false;
	}

	// description
	BinaryWriter bwDescs;
	bwDescs.Push(static_cast<uint32_t>(outputNode->Descriptions.size()));
	for (size_t descInd = 0; descInd < outputNode->Descriptions.size(); descInd++)
	{
		bwDescs.Push(static_cast<uint32_t>(descInd));
		bwDescs.Push(GetVectorFromStr(outputNode->Descriptions[descInd]->Summary));
		bwDescs.Push(GetVectorFromStr(outputNode->Descriptions[descInd]->Detail));
	}

	const char* chunk_desc = "DESC";
	auto size_descs = static_cast<int32_t>(bwDescs.GetBuffer().size());

	offset = data.size();
	data.resize(data.size() + 4);
	memcpy(data.data() + offset, chunk_desc, 4);

	offset = data.size();
	data.resize(data.size() + sizeof(int32_t));
	memcpy(data.data() + offset, &size_descs, sizeof(int32_t));

	offset = data.size();
	data.resize(data.size() + bwDescs.GetBuffer().size());
	memcpy(data.data() + offset, bwDescs.GetBuffer().data(), bwDescs.GetBuffer().size());

	// generic
	std::shared_ptr<TextExporter> textExporter = std::make_shared<TextExporter>();
	auto result = textExporter->Export(shared_from_this(), outputNode, "$SUFFIX");

	// flag

	// Lit or Unlit(Shading type)
	// Change normal
	// refraction
	BinaryWriter bwParam;
	bwParam.Push(result.ShadingModel);
	bwParam.Push(false);
	bwParam.Push(result.HasRefraction);
	bwParam.Push(result.CustomData1);
	bwParam.Push(result.CustomData2);

	bwParam.Push(static_cast<int32_t>(result.Textures.size()));

	for (size_t i = 0; i < result.Textures.size(); i++)
	{
		auto& param = result.Textures[i];
		auto name_ = GetVectorFromStr(Replace(param->Name, "$SUFFIX", ""));
		bwParam.Push(name_);

		// name is for human, uniformName is a variable name after 3
		auto uniformName = GetVectorFromStr(param->UniformName);
		bwParam.Push(uniformName);

		auto defaultPath_ = GetVectorFromStr(PathHelper::Relative(param->DefaultPath, std::string(basePath)));
		bwParam.Push(defaultPath_);
		bwParam.Push(param->Index);
		bwParam.Push(param->Priority);
		bwParam.Push(param->IsParam);
		bwParam.Push(param->Type);
		bwParam.Push(param->Sampler);
	}

	bwParam.Push(static_cast<int32_t>(result.Uniforms.size()));

	for (size_t i = 0; i < result.Uniforms.size(); i++)
	{
		auto& param = result.Uniforms[i];

		auto name_ = GetVectorFromStr(Replace(param->Name, "$SUFFIX", ""));
		bwParam.Push(name_);

		// name is for human, uniformName is a variable name after 3
		auto uniformName = GetVectorFromStr(param->UniformName);
		bwParam.Push(uniformName);

		bwParam.Push(param->Offset);
		bwParam.Push(param->Priority);
		int type = (int)(param->Type);
		bwParam.Push(type);

		bwParam.Push(param->DefaultConstants[0]);
		bwParam.Push(param->DefaultConstants[1]);
		bwParam.Push(param->DefaultConstants[2]);
		bwParam.Push(param->DefaultConstants[3]);
	}

	const char* chunk_para = "PRM_";
	auto size_para = static_cast<int32_t>(bwParam.GetBuffer().size());

	offset = data.size();
	data.resize(data.size() + 4);
	memcpy(data.data() + offset, chunk_para, 4);

	offset = data.size();
	data.resize(data.size() + sizeof(int32_t));
	memcpy(data.data() + offset, &size_para, sizeof(int32_t));

	offset = data.size();
	data.resize(data.size() + bwParam.GetBuffer().size());
	memcpy(data.data() + offset, bwParam.GetBuffer().data(), bwParam.GetBuffer().size());

	// param 2
	BinaryWriter bwParam2;

	if (version >= 2)
	{
		bwParam2.Push(static_cast<int32_t>(CustomData.size()));

		for (size_t ci = 0; ci < CustomData.size(); ci++)
		{
			bwParam2.Push(static_cast<int32_t>(CustomData[ci].Descriptions.size()));

			for (size_t descInd = 0; descInd < CustomData[ci].Descriptions.size(); descInd++)
			{
				bwParam2.Push(static_cast<uint32_t>(descInd));
				bwParam2.Push(GetVectorFromStr(CustomData[ci].Descriptions[descInd]->Summary));
				bwParam2.Push(GetVectorFromStr(CustomData[ci].Descriptions[descInd]->Detail));
			}
		}
	}

	bwParam2.Push(static_cast<int32_t>(result.Textures.size()));

	for (size_t i = 0; i < result.Textures.size(); i++)
	{
		bwParam2.Push(static_cast<int32_t>(result.Textures[i]->Descriptions.size()));

		for (size_t descInd = 0; descInd < result.Textures[i]->Descriptions.size(); descInd++)
		{
			bwParam2.Push(static_cast<uint32_t>(descInd));
			bwParam2.Push(GetVectorFromStr(result.Textures[i]->Descriptions[descInd]->Summary));
			bwParam2.Push(GetVectorFromStr(result.Textures[i]->Descriptions[descInd]->Detail));
		}
	}

	bwParam2.Push(static_cast<int32_t>(result.Uniforms.size()));

	for (size_t i = 0; i < result.Uniforms.size(); i++)
	{
		bwParam2.Push(static_cast<int32_t>(result.Uniforms[i]->Descriptions.size()));

		for (size_t descInd = 0; descInd < result.Uniforms[i]->Descriptions.size(); descInd++)
		{
			bwParam2.Push(static_cast<uint32_t>(descInd));
			bwParam2.Push(GetVectorFromStr(result.Uniforms[i]->Descriptions[descInd]->Summary));
			bwParam2.Push(GetVectorFromStr(result.Uniforms[i]->Descriptions[descInd]->Detail));
		}
	}

	const char* chunk_para2 = "PRM2";
	auto size_para2 = static_cast<int32_t>(bwParam2.GetBuffer().size());

	offset = data.size();
	data.resize(data.size() + 4);
	memcpy(data.data() + offset, chunk_para2, 4);

	offset = data.size();
	data.resize(data.size() + sizeof(int32_t));
	memcpy(data.data() + offset, &size_para2, sizeof(int32_t));

	offset = data.size();
	data.resize(data.size() + bwParam2.GetBuffer().size());
	memcpy(data.data() + offset, bwParam2.GetBuffer().data(), bwParam2.GetBuffer().size());

	// for Editor(CustomData)
	BinaryWriter bwEditorCD;
	bwEditorCD.Push(static_cast<int32_t>(CustomData.size()));
	for (size_t ci = 0; ci < CustomData.size(); ci++)
	{
		bwEditorCD.Push(CustomData[ci].Values[0]);
		bwEditorCD.Push(CustomData[ci].Values[1]);
		bwEditorCD.Push(CustomData[ci].Values[2]);
		bwEditorCD.Push(CustomData[ci].Values[3]);
	}

	const char* chunk_EditorCD = "E_CD";
	auto size_EditorCD = static_cast<int32_t>(bwEditorCD.GetBuffer().size());

	offset = data.size();
	data.resize(data.size() + 4);
	memcpy(data.data() + offset, chunk_EditorCD, 4);

	offset = data.size();
	data.resize(data.size() + sizeof(int32_t));
	memcpy(data.data() + offset, &size_EditorCD, sizeof(int32_t));

	offset = data.size();
	data.resize(data.size() + bwEditorCD.GetBuffer().size());
	memcpy(data.data() + offset, bwEditorCD.GetBuffer().data(), bwEditorCD.GetBuffer().size());

	BinaryWriter bwGene;

	{
		auto code_ = GetVectorFromStr(result.Code);
		bwGene.Push(code_);
	}

	const char* chunk_gene = "GENE";
	auto size_gene = static_cast<int32_t>(bwGene.GetBuffer().size());

	offset = data.size();
	data.resize(data.size() + 4);
	memcpy(data.data() + offset, chunk_gene, 4);

	offset = data.size();
	data.resize(data.size() + sizeof(int32_t));
	memcpy(data.data() + offset, &size_gene, sizeof(int32_t));

	offset = data.size();
	data.resize(data.size() + bwGene.GetBuffer().size());
	memcpy(data.data() + offset, bwGene.GetBuffer().data(), bwGene.GetBuffer().size());

	// data
	auto internalJsonVec = GetVectorFromStr(internalJson);
	const char* chunk_data = "DATA";
	auto size_data = static_cast<int32_t>(internalJsonVec.size());

	offset = data.size();
	data.resize(data.size() + 4);
	memcpy(data.data() + offset, chunk_data, 4);

	offset = data.size();
	data.resize(data.size() + sizeof(int32_t));
	memcpy(data.data() + offset, &size_data, sizeof(int32_t));

	offset = data.size();
	data.resize(data.size() + internalJsonVec.size());
	memcpy(data.data() + offset, internalJsonVec.data(), internalJsonVec.size());

	return true;
}

} // namespace EffekseerMaterial
