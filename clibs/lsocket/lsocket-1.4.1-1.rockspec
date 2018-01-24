package = "lsocket"
version = "1.4.1-1"
source = {
	url = "http://www.tset.de/downloads/lsocket-1.4.1-1.tar.gz"
}
description = {
	summary = "simple and easy socket support for lua.",
	detailed = [[
		lsocket is a library to provide socket programming support for
		lua. It is not intended to be a complete socket api, but easy to
		use and good enough for most tasks. IPv4, IPv6 and Unix Domain
		sockets are supported, as are tcp and udp, and also IPv4
		broadcasts and IPv6 multicasts.
	]],
	homepage = "http://www.tset.de/lsocket/",
	license = "MIT",
	maintainer = "Gunnar Zötl <gz@tset.de>"
}
supported_platforms = {
	"unix"
}
dependencies = {
	"lua >= 5.1, <= 5.3"
}

build = {
	type = "make",
	copy_directories = { 'doc', 'samples' },
	build_variables = {
			CFLAGS="$(CFLAGS)",
			LIBFLAG="$(LIBFLAG)",
			LUA_LIBDIR="$(LUA_LIBDIR)",
			LUA_BINDIR="$(LUA_BINDIR)",
			LUA_INCDIR="$(LUA_INCDIR)",
	},
	install_variables = {
			INST_PREFIX="$(PREFIX)",
			INST_BINDIR="$(BINDIR)",
			INST_LIBDIR="$(LIBDIR)",
			INST_LUADIR="$(LUADIR)",
			INST_CONFDIR="$(CONFDIR)",
	},
}
