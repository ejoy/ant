#include <RmlUi/Core/SystemInterface.h>

#include <chrono>
class System : public Rml::SystemInterface{
public:
    System();
    virtual double GetElapsedTime() override;
private:
    std::chrono::system_clock::time_point mStartTime;
};
