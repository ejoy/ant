#include "playbackcontroller.h"
#include <cmath>
#include "ozz/animation/runtime/animation.h"
#include "ozz/base/maths/math_ex.h"
namespace sample {
	PlaybackController::PlaybackController()
		: time_ratio_(0.f),
		previous_time_ratio_(0.f),
		playback_speed_(1.f),
		play_(true),
		loop_(true) {}

	void PlaybackController::update(const ozz::animation::Animation& _animation,
		float _dt) {
		float new_time = time_ratio_;

		if (play_) {
			new_time = time_ratio_ + _dt * playback_speed_ / _animation.duration();
		}

		// Must be called even if time doesn't change, in order to update previous
		// frame time ratio. Uses set_time_ratio function in order to update
		// previous_time_ an wrap time value in the unit interval (depending on loop
		// mode).
		set_time_ratio(new_time);
	}

	void PlaybackController::set_time_ratio(float _ratio) {
		previous_time_ratio_ = time_ratio_;
		if (loop_) {
			// Wraps in the unit interval [0:1], even for negative values (the reason
			// for using floorf).
			time_ratio_ = _ratio - floorf(_ratio);
		}
		else {
			// Clamps in the unit interval [0:1].
			time_ratio_ = ozz::math::Clamp(0.f, _ratio, 1.f);
		}
	}

	// Gets animation current time.
	float PlaybackController::time_ratio() const { return time_ratio_; }

	// Gets animation time of last update.
	float PlaybackController::previous_time_ratio() const {
		return previous_time_ratio_;
	}
	void PlaybackController::pause(bool pause) {
		play_ = !pause;
	}
	bool PlaybackController::is_playing() {
		return play_;
	}
	void PlaybackController::reset() {
		previous_time_ratio_ = time_ratio_ = 0.f;
		playback_speed_ = 1.f;
		play_ = true;
	}
}