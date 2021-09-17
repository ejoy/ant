#include "effect.h"

effect_adapter::effect_adapter(Effekseer::Manager* mgr,
	const Effekseer::EffectRef& effect)
	: manager_{ mgr }
	, effect_{ effect }
{

}

Effekseer::Handle effect_adapter::play(Effekseer::Handle handle)
{
	return play(handle, 0);
}

void effect_adapter::pause(Effekseer::Handle handle, bool p)
{
	if (handle == -1) {
		return;
	}
	if (auto it = play_objects_.find(handle); it != play_objects_.end()) {
		manager_->SetPaused(handle, p);
		it->second.playing = !p;
	}
}

Effekseer::Handle effect_adapter::play(Effekseer::Handle handle, int32_t startTime)
{
	if (!effect_.Get() || !manager_) {
		return -1;
	}
	stop(handle);
	handle = manager_->Play(effect_, {}, startTime);
	play_objects_.insert(std::pair<Effekseer::Handle, play_object>(handle, {}));
	auto& play_obj = play_objects_[handle];
	play_objects_[handle].tranform.Indentity();
	manager_->SetMatrix(handle, play_obj.tranform);
	manager_->SetSpeed(handle, play_obj.speed);
	play_obj.stop = false;
	return handle;
}

Effekseer::Handle effect_adapter::set_time(Effekseer::Handle handle, int32_t frame, bool shouldExist)
{
	if (!effect_.Get() || !manager_ || frame < 0.0f) {
		return handle;
	}
	if (!manager_->Exists(handle)) {
		if (shouldExist) {
			return handle;
		}
		handle = play(handle);
		pause(handle, true);
	}
	manager_->SetPaused(handle, false);
	manager_->UpdateHandleToMoveToFrame(handle, frame);
	manager_->SetPaused(handle, !play_objects_[handle].playing);
	return handle;
}

void effect_adapter::set_target_pos(Effekseer::Handle handle, const Effekseer::Vector3D& pos)
{
	manager_->SetTargetLocation(handle, pos.X, pos.Y, pos.Z);
}

bool effect_adapter::get_loop(Effekseer::Handle handle)
{
	if (handle == -1) {
		return false;
	}
	if (auto it = play_objects_.find(handle); it != play_objects_.end()) {
		return it->second.loop;
	}
	return false;
}

void effect_adapter::set_loop(Effekseer::Handle handle, bool value)
{
	if (auto it = play_objects_.find(handle); it != play_objects_.end()) {
		it->second.loop = value;
	}
}

float effect_adapter::get_speed(Effekseer::Handle handle)
{
	if (auto it = play_objects_.find(handle); it != play_objects_.end()) {
		return it->second.speed;
	}
	return 0.0;
}

void effect_adapter::set_speed(Effekseer::Handle handle, float speed)
{
	if (auto it = play_objects_.find(handle); it != play_objects_.end()) {
		play_objects_[handle].speed = speed;
		manager_->SetSpeed(handle, speed);
	}
}

bool effect_adapter::is_playing(Effekseer::Handle handle)
{
	return manager_->Exists(handle);
}

void effect_adapter::stop(Effekseer::Handle handle)
{
	if (handle == -1) {
		return;
	}
	manager_->StopEffect(handle);
	auto it = play_objects_.find(handle);
	if (it != play_objects_.end()) {
		play_objects_.erase(it);
	}
}

void effect_adapter::stop_root(Effekseer::Handle handle)
{
	if (handle == -1) {
		return;
	}
	manager_->StopRoot(handle);
	auto it = play_objects_.find(handle);
	if (it != play_objects_.end()) {
		play_objects_.erase(it);
	}
}

void effect_adapter::set_tranform(Effekseer::Handle handle, const Effekseer::Matrix43& mat)
{
	if (auto it = play_objects_.find(handle); it != play_objects_.end()) {
		it->second.tranform = mat;
	}
}

void effect_adapter::update()
{
	for (auto it = play_objects_.begin(); it != play_objects_.end();) {
		if (!manager_->Exists(it->first)) {
			it = play_objects_.erase(it);
		} else {
			manager_->SetMatrix(it->first, it->second.tranform);
			++it;
		}
	}
}

void effect_adapter::destroy()
{
	for (auto it = play_objects_.begin(); it != play_objects_.end(); ++it) {
		manager_->StopEffect(it->first);
	}
	play_objects_.clear();
	effect_.Reset();
}