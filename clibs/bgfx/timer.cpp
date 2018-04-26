#include <bx/timer.h>

extern "C"{
    int64_t get_HP_counter(){
        return bx::getHPCounter();
    }

    int64_t get_HP_frequency(){
        return bx::getHPFrequency();
    }
}