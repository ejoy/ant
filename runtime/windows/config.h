#ifndef ant_windows_config_h
#define ant_windows_config_h

struct ant_client_config {
	int width;
	int height;
	char title[64];
	char bootstrap[1024];
};

int antclient_loadconfig(const char *configpath, struct ant_client_config *result);

#endif
