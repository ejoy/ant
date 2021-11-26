#include <vector>
namespace FMOD::Studio {
	class System;
	class Bank;
	class EventInstance;
}
class audio {
public:
	audio() = default;
	~audio() = default;
	static audio& instance();
	bool init();
	bool update();
	void release();
	bool load_bank(const char* buffer, int length);
	FMOD::Studio::EventInstance* create_event(const char* event_name);
private:
	FMOD::Studio::System* studio_;
	std::vector<FMOD::Studio::Bank*> all_bank_;
};