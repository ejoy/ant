#pragma once
#include <RmlUi/Core/SystemInterface.h>

#include <chrono>
class System : public Rml::SystemInterface{
public:
    System();
    virtual double GetElapsedTime() override;
    virtual void JoinPath(Rml::String& translated_path, const Rml::String& document_path, const Rml::String& path) override;
private:
    std::chrono::system_clock::time_point mStartTime;
};
