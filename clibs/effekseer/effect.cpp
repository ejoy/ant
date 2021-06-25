#include "effect.h"

effect_adapter::effect_adapter(Effekseer::Manager* mgr,
	const Effekseer::EffectRef& effect)
	: manager_{ mgr }
	, effect_{ effect }
{
	tranform_.Indentity();
}

void effect_adapter::play()
{
	play(0);
}

void effect_adapter::pause(bool p)
{
	if (handle_ != -1)
	{
		manager_->SetPaused(handle_, p);
	}
}

void effect_adapter::play(int32_t startTime)
{
	if (!effect_.Get() || !manager_)
	{
		return;
	}
	Effekseer::Vector3D t;
	tranform_.GetTranslation(t);
	handle_ = manager_->Play(effect_, t, startTime);
	manager_->SetSpeed(handle_, speed_);
}

void effect_adapter::set_target_pos(const Effekseer::Vector3D& pos)
{
	target_position_ = pos;
	manager_->SetTargetLocation(handle_, pos.X, pos.Y, pos.Z);
}

bool effect_adapter::get_loop()
{
	return loop_;
}

void effect_adapter::set_loop(bool value)
{
	loop_ = value;
}

float effect_adapter::get_speed()
{
	return speed_;
}

void effect_adapter::set_speed(float speed)
{
	speed_ = speed;
	manager_->SetSpeed(handle_, speed);
}

bool effect_adapter::is_playing()
{
	return manager_->Exists(handle_);
}

void effect_adapter::stop()
{
	if (handle_ != -1) {
		manager_->StopEffect(handle_);
	}
}

void effect_adapter::stop_root()
{
	if (handle_ != -1) {
		manager_->StopRoot(handle_);
	}
}

void effect_adapter::set_tranform(const Effekseer::Matrix43& mat)
{
	tranform_ = mat;
}

void effect_adapter::update()
{
	if (!manager_->Exists(handle_))
	{
		if (loop_)
		{
			play();
		}
	}
	else
	{
		manager_->SetMatrix(handle_, tranform_);
	}
}

void effect_adapter::destroy()
{
	manager_->StopEffect(handle_);
	handle_ = -1;
	effect_.Reset();
}