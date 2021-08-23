#pragma once

#include <Effekseer.h>
class effect_adapter
{
public:
	effect_adapter(Effekseer::Manager* mgr,
		const Effekseer::EffectRef& effect);
	void set_tranform(const Effekseer::Matrix43& mat);
	void play();
	void pause(bool p);
	void play(int32_t startTime);
	void set_time(int32_t time, bool shouldExist = true);
	bool get_loop();
	void set_loop(bool value);
	float get_speed();
	void set_speed(float speed);
	bool is_playing();
	void stop();
	void stop_root();
	void set_target_pos(const Effekseer::Vector3D& pos);
	void update();
	void destroy();
private:
	float					speed_{ 1.0f };
	bool					loop_{ false };
	bool					playing{ true };
	Effekseer::Vector3D		target_position_;
	Effekseer::Manager*		manager_{ nullptr };
	Effekseer::EffectRef	effect_{ nullptr };
	Effekseer::Handle		handle_{ -1 };
	Effekseer::Matrix43		tranform_;
};