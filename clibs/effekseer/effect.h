#pragma once

#include <Effekseer.h>
class effect_adapter
{
public:
	effect_adapter(Effekseer::Manager* mgr,
		const Effekseer::EffectRef& effect);
	void set_tranform(Effekseer::Handle handle, const Effekseer::Matrix43& mat);
	Effekseer::Handle play(Effekseer::Handle handle);
	void pause(Effekseer::Handle handle, bool p);
	Effekseer::Handle play(Effekseer::Handle handle, int32_t startTime);
	Effekseer::Handle set_time(Effekseer::Handle handle, int32_t time, bool shouldExist = true);
	bool get_loop(Effekseer::Handle handle);
	void set_loop(Effekseer::Handle handle, bool value);
	float get_speed(Effekseer::Handle handle);
	void set_speed(Effekseer::Handle handle, float speed);
	void set_visible(Effekseer::Handle handle, bool value);
	bool is_playing(Effekseer::Handle handle);
	void stop(Effekseer::Handle handle);
	void stop_root(Effekseer::Handle handle);
	void set_target_pos(Effekseer::Handle handle, const Effekseer::Vector3D& pos);
	void update();
	void destroy();
private:
	Effekseer::Manager*		manager_{ nullptr };
	Effekseer::EffectRef	effect_{ nullptr };
	struct play_object
	{
		play_object() {
			tranform.Indentity();
		}
		float				speed{ 1.0f };
		bool				loop{ false };
		bool				playing{ true };
		bool				stop{ true };
		Effekseer::Vector3D	target{};
		Effekseer::Handle	handle{ -1 };
		Effekseer::Matrix43	tranform;
	};
	std::unordered_map<Effekseer::Handle, play_object> play_objects_;
};