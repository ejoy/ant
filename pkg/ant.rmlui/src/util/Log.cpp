#include <util/Log.h>
#include <binding/Context.h>
#include <stdarg.h>
#include <stdio.h>

namespace Rml {

void Log::Message(Level level, const char* fmt, ...) {
	const int buffer_size = 1024;
	char buffer[buffer_size];
	va_list argument_list;

	va_start(argument_list, fmt);
	int len = vsnprintf(buffer, buffer_size - 2, fmt, argument_list);	
	if (len < 0 || len > buffer_size - 2)	
	{
		len = buffer_size - 2;
	}	
	buffer[len] = '\0';
	va_end(argument_list);

	fprintf(stderr,"%s\n", buffer);
}

}
