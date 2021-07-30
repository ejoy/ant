#include "pch.h"
#include "system.h"
#include <assert.h>

SystemInterface::SystemInterface()
    : current_time(0){
}

void SystemInterface::update(double delta) {
    current_time += delta;
}

double SystemInterface::GetElapsedTime(){
    return current_time / 1000.;
}
