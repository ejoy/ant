#include "efkMat.CommandManager.h"

namespace EffekseerMaterial
{
DelegateCommand::DelegateCommand(const std::function<void()>& execute, const std::function<void()>& unexecute)
	: execute(execute), unexecute(unexecute)
{
}

DelegateCommand::~DelegateCommand() {}

void DelegateCommand::Execute() { execute(); }

void DelegateCommand::Unexecute() { unexecute(); }

CommandCollection::CommandCollection() {}
CommandCollection::~CommandCollection() {}

void CommandCollection::AddCommand(std::shared_ptr<ICommand> command)
{
	if (commands.size() > 0)
	{
		if (command->Merge(commands.back().get()))
		{
			commands.back() = command;
		}
		else
		{
			commands.push_back(command);
		}
	}
	else
	{
		commands.push_back(command);
	}
}

void CommandCollection::Execute()
{
	for (auto c : commands)
	{
		c->Execute();
	}
}

void CommandCollection::Unexecute()
{
	for (int32_t i = static_cast<int32_t>(commands.size()) - 1; i >= 0; i--)
	{
		commands[i]->Unexecute();
	}
}

void CommandManager::StartCollection()
{
	if (collectionCount == 0)
	{
		collection = std::make_shared<CommandCollection>();
	}

	collectionCount++;
}

void CommandManager::EndCollection()
{
	collectionCount--;

	if (collectionCount == 0)
	{
		Execute(collection);
		collection = nullptr;
	}
}

void CommandManager::Execute(std::shared_ptr<ICommand> command)
{
	if (collectionCount > 0)
	{
		collection->AddCommand(command);
		command->Execute();
	}
	else
	{
		commands.resize(commandInd);

		if (commands.size() > 0)
		{
			if (isMergeEnabled && command->Merge(commands.back().get()))
			{
				commands.back() = command;
			}
			else
			{
				commands.push_back(command);
				commandInd++;
			}
		}
		else
		{
			commands.push_back(command);
			commandInd++;
		}

		command->Execute();
		isMergeEnabled = true;
	}

	historyID++;
}

void CommandManager::Undo()
{
	if (collectionCount > 0)
		return;
	if (commandInd == 0)
		return;
	commands[commandInd - 1]->Unexecute();
	commandInd--;
	historyID++;
}

void CommandManager::Redo()
{
	if (collectionCount > 0)
		return;
	if (commandInd == commands.size())
		return;
	commands[commandInd]->Execute();
	commandInd++;
	historyID++;
}

void CommandManager::Reset()
{
	commands.clear();
	commandInd = 0;
	collectionCount = 0;
	historyID = 0;
}

void CommandManager::MakeMergeDisabled() { isMergeEnabled = false; }

uint64_t CommandManager::GetHistoryID() { return historyID; }

} // namespace EffekseerMaterial
