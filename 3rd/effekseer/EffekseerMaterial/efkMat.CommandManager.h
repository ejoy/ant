
#pragma once

#include "efkMat.Base.h"
#include "efkMat.Models.h"
#include "efkMat.Parameters.h"

namespace EffekseerMaterial
{

class ICommand
{
public:
	ICommand() = default;
	virtual ~ICommand() = default;
	virtual void Execute() {}
	virtual void Unexecute() {}
	virtual bool Merge(ICommand* command) { return false; }
	virtual const char* GetTag() { return nullptr; }
};

class DelegateCommand : public ICommand
{
private:
	std::function<void()> execute;
	std::function<void()> unexecute;

public:
	DelegateCommand(const std::function<void()>& execute, const std::function<void()>& unexecute);

	virtual ~DelegateCommand();

	void Execute() override;

	void Unexecute() override;
};

class CommandCollection : public ICommand
{
private:
	std::vector<std::shared_ptr<ICommand>> commands;

public:
	CommandCollection();
	virtual ~CommandCollection();

	void AddCommand(std::shared_ptr<ICommand> command);

	void Execute();

	void Unexecute();
};

class CommandManager
{
private:
	std::vector<std::shared_ptr<ICommand>> commands;
	int32_t commandInd = 0;
	int32_t collectionCount = 0;
	std::shared_ptr<CommandCollection> collection;

	std::function<void()> executed;
	std::function<void()> unexecuted;

	bool isMergeEnabled = false;

	//! to check whether parameters are changed
	uint64_t historyID = 0;

	static std::shared_ptr<CommandManager> instance;

public:
	CommandManager() = default;
	virtual ~CommandManager() = default;

	void StartCollection();

	void EndCollection();

	void Execute(std::shared_ptr<ICommand> command);

	void Undo();

	void Redo();

	void Reset();

	void MakeMergeDisabled();

	uint64_t GetHistoryID();
};

} // namespace EffekseerMaterial