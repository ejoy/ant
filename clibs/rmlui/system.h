#pragma once

#include <RmlUi/SystemInterface.h>

class SystemInterface : public Rml::SystemInterface {
public:
    SystemInterface();
    virtual double GetElapsedTime() override;
    
    void update(double delta);
private:
    double current_time;
};
