#include "pch.h"
#include "system.h"

System::System()
    : mStartTime(std::chrono::system_clock::now()){
}

double System::GetElapsedTime(){
    auto now = std::chrono::system_clock::now();
    auto duration = now - mStartTime;
	return duration.count();
}