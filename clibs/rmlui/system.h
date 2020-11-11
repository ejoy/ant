#pragma once

#include <RmlUi/Core/SystemInterface.h>
#include <chrono>

class SystemInterface : public Rml::SystemInterface {
public:
    SystemInterface();
    virtual double GetElapsedTime() override;
    virtual void JoinPath(Rml::String& translated_path, const Rml::String& document_path, const Rml::String& path) override;
private:
    std::chrono::steady_clock::time_point mStartTime;
};
