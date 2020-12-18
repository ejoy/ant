#include "pch.h"
#include "emitter.h"
#include "random.h"
#include "particle_mgr.h"
#include "particle.inl"
#include "lua2struct.h"
#include "debug_print.h"

LUA2STRUCT(struct particle_emitter::spawndata, count, rate);

static inline bool
has_comp(const comp_ids &ids, component_id id){
	return std::find(ids.begin(), ids.end(), id) != ids.end();
}

static inline bool
need_base_comp(const comp_ids &ids, component_id id, component_id base_id){
	return (has_comp(ids, id)) && !has_comp(ids, base_id);
}

static inline void
check_add_id(comp_ids &ids, component_id id){
	if (std::find(ids.begin(), ids.end(), id) == ids.end())
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
	debug_print("spawn:", mspawn.step.count, "loop:", mspawn.step.loop);
}

static void check_add_default_component(comp_ids &ids){
	if (has_comp(ids, ID_TAG_render_quad)){
		const auto &dq = quaddata::default_quad();
		if (!has_comp(ids, ID_color))
			ids.push_back(particle_mgr::get().add_component(particles::color(0xff)));
		if (!has_comp(ids, ID_translation))
			ids.push_back(particle_mgr::get().add_component(particles::translation(0.f)));

		if (!has_comp(ids, ID_uv)){
			particles::uv uv; for(int ii=0; ii<4; ++ii) uv.uv[ii] = dq[ii].uv;
			ids.push_back(particle_mgr::get().add_component(uv));
		}

		if (!has_comp(ids, ID_subuv)){
			particles::subuv subuv; for(int ii=0; ii<4; ++ii) subuv.uv[ii] = dq[ii].subuv;
			ids.push_back(particle_mgr::get().add_component(subuv));
		}
	}

	if (need_base_comp(ids, ID_color_interpolator, ID_color)){
		ids.push_back(particle_mgr::get().add_component(particles::color(0xff)));
	}

	if (need_base_comp(ids, ID_acceleration_interpolator, ID_acceleration)){
		ids.push_back(particle_mgr::get().add_component(particles::acceleration(0.f)));
	}

	if (need_base_comp(ids, ID_translation_interpolator, ID_translation)){
		ids.push_back(particle_mgr::get().add_component(particles::translation(0.f)));
	}

	if (need_base_comp(ids, ID_uv_motion_interpolator, ID_uv_motion)){
		particles::uv_motion uvm;
		uvm.speed = glm::vec2(0.f);
		uvm.type = uv_motion::mt_speed;
		ids.push_back(particle_mgr::get().add_component(uvm));
	}

	if (need_base_comp(ids, ID_subuv_motion_interpolator, ID_uv_motion)){
		particles::subuv_motion sub_uvm;
		sub_uvm.speed = glm::vec2(0.f);
		sub_uvm.type = uv_motion::mt_speed;
		ids.push_back(particle_mgr::get().add_component(sub_uvm));
	}

	if (need_base_comp(ids, ID_acceleration, ID_velocity)){
		ids.push_back(particle_mgr::get().add_component(particles::velocity(0.f)));
	}

	if (need_base_comp(ids, ID_velocity, ID_translation)){
		ids.push_back(particle_mgr::get().add_component(particles::translation(0.f)));
	}

	if (need_base_comp(ids, ID_uv_motion, ID_uv)){
		const auto &dq = quaddata::default_quad();
		particles::uv uv; for(int ii=0; ii<4; ++ii) uv.uv[ii] = dq[ii].uv;
		ids.push_back(particle_mgr::get().add_component(uv));
	}

	if (need_base_comp(ids, ID_subuv_motion, ID_subuv)){
		const auto &dq = quaddata::default_quad();
		particles::subuv subuv; for(int ii=0; ii<4; ++ii) subuv.uv[ii] = dq[ii].subuv;
		ids.push_back(particle_mgr::get().add_component(subuv));
	}
}

template<typename UVM_TYPE, typename INIT_UVMTYPE>
static void create_uvm(UVM_TYPE &uvm, const INIT_UVMTYPE &init_uvm, randomobj &ro){
	uvm.type = init_uvm.type;
	if (uvm.type == uv_motion::mt_speed){
		uvm.speed = init_uvm.speed.get(ro());
	} else {
		assert(uvm.type == uv_motion::mt_index);
		uvm.index.idx = 0;
		uvm.index.rate = uv_motion::TO_FIXPOINT(init_uvm.index.rate.get(ro()));
		uvm.index.dim = init_uvm.index.dim;
	}
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
		case ID_uv_motion:{
			particles::uv_motion uvm;
			create_uvm(uvm, mspawn.init.uv_motion, ro);
			check_add_id(ids, particle_mgr::get().add_component(uvm));
		} break;
		case ID_subuv_motion:{
			particles::subuv_motion sub_uvm;
			create_uvm(sub_uvm, mspawn.init.subuv_motion, ro);
			check_add_id(ids, particle_mgr::get().add_component(sub_uvm));
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
		case ID_color_interpolator: {
			assert(std::find(ids.begin(), ids.end(), ID_color) != ids.end());
			check_add_id(ids, particle_mgr::get().add_component(
				particles::color_interpolator(mspawn.interp.color)
			));
		} break;
		default: assert(false && "not support type"); break;
		}
	}

	check_add_default_component(ids);

    particle_mgr::get().add(ids);
	return --mspawn.step.count;
}