#pragma once

#include <RmlUi/Core/SystemInterface.h>

class SystemInterface : public Rml::SystemInterface {
public:
    SystemInterface();
    virtual double GetElapsedTime() override;
    virtual void JoinPath(Rml::String& translated_path, const Rml::String& document_path, const Rml::String& path) override;
    
    void update(double delta);
private:
    double current_time;
};
