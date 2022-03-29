
#pragma once

#include "efkMat.Base.h"
#include "efkMat.Models.h"
#include "efkMat.Parameters.h"
#include <cctype>

namespace EffekseerMaterial
{

class LibraryContentBase
{
public:
	LibraryContentBase() = default;
	virtual ~LibraryContentBase() = default;

	std::string Name;
	std::string Description;
	std::vector<std::string> Group;
	std::vector<std::string> Keywords;

	//! shown in editor
	std::string KeywordsShown;

	bool IsShown = true;

	virtual std::shared_ptr<NodeParameter> Create() { return nullptr; }
};

template <class NT> class LibraryContent : public LibraryContentBase
{
	std::string tolower(std::string s)
	{
		std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) { return std::tolower(c); });
		return s;
	}

public:
	LibraryContent()
	{
		auto node = Create();
		Name = node->TypeName;
		Description = node->Description;
		Group = node->Group;

		Keywords.push_back(tolower(node->TypeName));

		for (auto key : node->Keywords)
		{
			Keywords.push_back(tolower(key));
		}

		if (node->Type == NodeType::Output)
		{
			IsShown = false;
		}

		for (size_t i = 0; i < Keywords.size(); i++)
		{
			KeywordsShown += Keywords[i];
			if (i != Keywords.size() - 1)
			{
				KeywordsShown += ", ";
			}
		}
	}

	std::shared_ptr<NodeParameter> Create() override { return std::make_shared<NT>(); }
};

class LibraryContentGroup
{
public:
	std::string Name;
	std::vector<std::shared_ptr<LibraryContentBase>> Contents;
	std::vector<std::shared_ptr<LibraryContentGroup>> Groups;
};

class Library
{

public:
	std::vector<std::shared_ptr<LibraryContentBase>> Contents;

	std::shared_ptr<LibraryContentGroup> Root;

	void MakeGroups();

	std::shared_ptr<LibraryContentBase> FindContentWithTypeName(const char* name)
	{
		auto key = std::string(name);

		for (auto content : Contents)
		{
			if (content->Name == key)
				return content;
		}

		return std::shared_ptr<LibraryContentBase>();
	}

	Library();
	virtual ~Library();
};

} // namespace EffekseerMaterial