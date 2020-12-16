#include "pch.h"
#include "emitter.h"
#include "random.h"
#include "particle_mgr.h"
#include "particle.inl"
#include "lua2struct.h"

LUA2STRUCT(struct particle_emitter::spawndata, count, rate);

static inline void
check_add_id(comp_ids &ids, component_id id){
	assert(std::find(ids.begin(), ids.end(), id) == ids.end());
	ids.push_back(id);
}

bool
particle_emitter::update(float dt){
	step(dt);
	return update_lifetime(dt);
}

void
particle_emitter::step(float dt){
	auto delta_spawn = [](auto &spawn){
		auto t = std::fmodf(spawn.step.loop, spawn.rate);
		auto step = t / spawn.rate;
		return (uint32_t)(step * spawn.count);
	};

	auto already_spawned = delta_spawn(mspawn);
	mspawn.step.loop += dt;
	auto totalnum = delta_spawn(mspawn);
	mspawn.step.count = (totalnum < already_spawned ? mspawn.count : totalnum) - already_spawned;
}

uint32_t
particle_emitter::spawn(const glm::mat4 &transform){
	if (0 == mspawn.step.count)
		return 0;

	randomobj ro;

	auto transform_init_value = [&transform](const interpolation::f3_init_value &iv, float e4){
		auto tmp = iv;
		tmp.minv = transform * glm::vec4(tmp.minv, e4);
		tmp.maxv = transform * glm::vec4(tmp.maxv, e4);

		return tmp;
	};

	auto transform_interp_value = [&transform](const interpolation::f3_interpolator& iv, float e4) {
		auto tmp = iv;
		tmp.scale = transform * glm::vec4(tmp.scale, e4);
		return tmp;
	};

    comp_ids ids;
    ids.push_back(ID_TAG_render_quad);
    for (auto id : mspawn.init.components){
		switch (id) {
		case ID_life:{
			check_add_id(ids, particle_mgr::get().add_component(
				particles::life(mspawn.init.life.get(ro()))
			));
		} break;
		case ID_velocity:{
			check_add_id(ids, particle_mgr::get().add_component(
				particles::velocity(transform_init_value(mspawn.init.velocity, 0.f).get(ro()))
			));
		} break;
		case ID_acceleration:{
			check_add_id(ids, particle_mgr::get().add_component(
				particles::acceleration(transform_init_value(mspawn.init.acceleration, 0.f).get(ro()))
			));
		} break;
		case ID_scale:{
			check_add_id(ids, particle_mgr::get().add_component(
				particles::scale(transform_init_value(mspawn.init.scale, 0.f).get(ro()))
			));
		} break;
		case ID_rotation:{
			// check_add_id(ids, particle_mgr::get().add_component(
			// 	particles::scale(spawn.init.scale.get(ro()))
			// ));
		} break;
		case ID_translation:{
			check_add_id(ids, particle_mgr::get().add_component(
				particles::translation(transform_init_value(mspawn.init.translation, 1.f).get(ro()))
			));
		} break;
		case ID_uv:{
			
		} break;
		case ID_uv_motion:{
			check_add_id(ids, particle_mgr::get().add_component(
				particles::uv_motion(mspawn.init.uv_motion.get(ro()))
			));
		} break;
		case ID_subuv:{

		} break;
		case ID_color:{
			particles::color c;
			for(int ii=0; ii<4;++ii){
				c[ii] = to_color_channel(mspawn.init.color.rgba[ii].get(ro()));
			}
			check_add_id(ids, particle_mgr::get().add_component(c));
		} break;
		case ID_material:{
			check_add_id(ids, particle_mgr::get().add_component(particles::material(mspawn.init.material)));
		} break;
		default: assert(false); break;
		}
	}

    for (auto id : mspawn.interp.components){
		switch (id){
		case ID_velocity_interpolator: {
			check_add_id(ids, particle_mgr::get().add_component(
				particles::velocity_interpolator(transform_interp_value(mspawn.interp.velocity, 0.f))
			));
		} break;
		case ID_acceleration_interpolator: {
			check_add_id(ids, particle_mgr::get().add_component(
				particles::acceleration_interpolator(transform_interp_value(mspawn.interp.acceleration, 0.f))
			));
		} break;
		case ID_scale_interpolator: {
			check_add_id(ids, particle_mgr::get().add_component(
				particles::scale_interpolator(transform_interp_value(mspawn.interp.scale, 0.f))
			));
		} break;
		case ID_rotation_interpolator: {
			// if (std::find(ids.begin(), ids.end(), ID_rotation) != ids.end()){
			// 	check_add_id(ids, particle_mgr::get().add_component(particles::rotation(0.f)));
			// }
			// check_add_id(ids, particle_mgr::get().add_component(
			// 	particles::rotation_interpolator(spawn.interp.rotation)
			// ));
		} break;
		case ID_translation_interpolator: {
			check_add_id(ids, particle_mgr::get().add_component(
				particles::translation_interpolator(transform_interp_value(mspawn.interp.translation, 1.f))
			));
		} break;
		case ID_uv_motion_interpolator: {
			check_add_id(ids, particle_mgr::get().add_component(
				particles::uv_motion_interpolator(mspawn.interp.uv_motion)
			));
		} break;
		case ID_subuv: {
			check_add_id(ids, particle_mgr::get().add_component(
				particles::subuv(mspawn.init.subuv)
			));
		} break;
		case ID_subuv_index_interpolator: {
			assert(std::find(ids.begin(), ids.end(), ID_subuv) != ids.end());
			check_add_id(ids, particle_mgr::get().add_component(
				particles::subuv_index_interpolator(mspawn.interp.subuv_index)
			));
		} break;
		case ID_color_interpolator: {
			assert(std::find(ids.begin(), ids.end(), ID_color) != ids.end());
			check_add_id(ids, particle_mgr::get().add_component(
				particles::color_interpolator(mspawn.interp.color)
			));
		} break;
		}
	}

    particle_mgr::get().add(ids);
	return --mspawn.step.count;
}