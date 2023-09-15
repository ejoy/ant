local platform = require "bee.platform"

local plist = require "plist"

local USBMUXD_SOCKET_PORT = 27015
local USBMUXD_SOCKET_FILE = "/var/run/usbmuxd"	-- for unix socket
local proto_version = 1

-- usbmuxd_header  LLLL
--  uint32_t length;    // length of message, including header
--  uint32_t version;   // protocol version
--  uint32_t message;   // message type
--  uint32_t tag;       // responses to this query will echo back this tag

-- usbmuxd_result_msg  usbmuxd_header + L
--  uint32_t result

-- usbmuxd_connect_request usbmuxd_header + LHH
--  uint32_t device_id;
--  uint16_t port;   // TCP port number
--  uint16_t reserved;   // set to zero

-- usbmuxd_listen_request usbmuxd_header

-- usbmuxd_device_record LHc256HL
--  uint32_t device_id;
--  uint16_t product_id;
--  char serial_number[256];
--  uint16_t padding;
--  uint32_t location;

local usbmuxd_result = {
	OK = 0,
	BADCOMMAND = 1,
	BADDEV = 2,
	CONNREFUSED = 3,
	BADVERSION = 6,
}

local usbmuxd_msgtype = {
	RESULT  = 1,
	CONNECT = 2,
	LISTEN = 3,
	DEVICE_ADD = 4,
	DEVICE_REMOVE = 5,
	DEVICE_PAIRED = 6,
	PLIST = 8,
}

local usbmuxd = {}

local function create_plist_message(message_type)
	local object = plist.dict {
		BundleID = "org.libimobiledevice.usbmuxd",
		ClientVersionString = "usbmuxd in lua",
		ProgName = "libusbmuxd",
		kLibUSBMuxVersion = 3,
		MessageType = message_type,
	}
	return object
end

local function plist_package(plist_object, tag)
	local payload = plist.toxml(plist_object)
	local length = 16 + #payload
	-- usbmuxd_header
	local header = string.pack("<I4I4I4I4", length, proto_version, usbmuxd_msgtype.PLIST, tag)
	return header, payload
end

function usbmuxd.get_address()
	if platform.os == "windows" then
		-- Windows
		return "tcp", "127.0.0.1", USBMUXD_SOCKET_PORT
	else
		return "unix", USBMUXD_SOCKET_FILE
	end
end

function usbmuxd.create_listen_package()
	local msg = create_plist_message "Listen"
	return plist_package(msg, 1)
end

function usbmuxd.create_connect_package(device_id, port)
	local msg = create_plist_message "Connect"
	msg.DeviceID = device_id
	msg.PortNumber = ('>I2'):unpack(('=I2'):pack(port))
	return plist_package(msg, 1)
end

function usbmuxd.recv(recvf)
	local sz = recvf(4)
	if sz == nil then
		return
	end
	local n = string.unpack("<I4", sz)
	local payload = recvf(n-4)
	if payload == nil then
		return
	end
	local version, message, tag, unread = string.unpack("<I4I4I4", payload)
	assert(version == proto_version)
	assert(message == usbmuxd_msgtype.PLIST)
	return plist.fromxml(payload:sub(unread)), tag
end

return usbmuxd
