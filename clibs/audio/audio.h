#include <vector>
namespace FMOD::Studio {
	class System;
	class Bank;
	class EventInstance;
	class EventDescription;
}
class audio {
public:
	audio() = default;
	~audio() = default;
	static audio& instance();
	bool init();
	bool update();
	void release();
	FMOD::Studio::Bank* load_bank(const char* buffer, int length);
	void unload_bank(FMOD::Studio::Bank* bank);
	FMOD::Studio::EventInstance* create_event(const char* event_name);
	void get_bank_count(int* count);
	void get_bank_list(FMOD::Studio::Bank** list, int capacity, int* count);
	void get_event_count(FMOD::Studio::Bank* bank, int* count);
	void get_event_list(FMOD::Studio::Bank* bank, FMOD::Studio::EventDescription** list, int capacity, int* count);
private:
	FMOD::Studio::System* studio_;
	std::vector<FMOD::Studio::Bank*> all_bank_;
};