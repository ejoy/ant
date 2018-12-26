local log = log and log(...) or print
local require = import and import(...) or require

local network = require "network"
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
local use_tag = 0

local function connect_usbmuxd_socket()
	-- todo: use unix socket
	return assert(network.connect("127.0.0.1", USBMUXD_SOCKET_PORT))
end

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

local function send_plist_package(fd, plist_object, tag)
	local payload = plist.toxml(plist_object)
	local length = 16 + #payload
	-- usbmuxd_header
	local header = string.pack("<LLLL", length, proto_version, usbmuxd_msgtype.PLIST, tag)
	network.send(fd, header)
	network.send(fd, payload)
end

local function recv_package(fd)
	local rd = fd._read[1]
	if rd then
		local n = #rd
		if n >= 4 then
			local length = string.unpack("<L", rd)
			if length <= n then
				if length == n then
					table.remove(fd._read, 1)
					return rd
				end
				fd._read[1] = rd:sub(length+1)
				return rd:sub(1, length)
			end
			if fd._read[2] then
				rd = table.concat(fd._read)
				for k in ipairs(fd._read) do
					fd._read[k] = nil
				end
				n = #rd
				if length <= n then
					if length == n then
						return rd
					end
					fd.read[1] = rd:sub(length+1)
					return rd:sub(1, length)
				end
			end
		end
	end
end

local function print_package(payload)
	local length, version, message, tag, unread = string.unpack("<LLLL", payload)
	print("Length=", length, "Version=", version, "Message=", message, "Tag=", tag)
	if message == usbmuxd_msgtype.PLIST then
		local msg = plist.fromxml(payload:sub(unread))
		print_r(msg)
	end
end

local function listen()
	local fd = connect_usbmuxd_socket()
	use_tag = use_tag + 1

	local msg = create_plist_message "Listen"
	send_plist_package(fd, msg, use_tag)

	return fd
end

--local function list_devices(fd)
--	use_tag = use_tag + 1
--	local msg = create_plist_message "ListDevices"
--	send_plist_package(fd, msg, use_tag)
--end

local function connect_socket(fd, device_id, port)
	local msg = create_plist_message "Connect"
	msg.DeviceID = device_id
	msg.PortNumber = port
	send_plist_package(fd, msg, 0)
end

function usbmuxd.mainloop()
	local monitor = listen()
--	list_devices(monitor)
	local objs = {}
	while true do
		if network.dispatch(objs) then
			for k,obj in ipairs(objs) do
				objs[k] = nil
				if obj == monitor then
					while true do
						local payload = recv_package(monitor)
						if payload then
							print_package(payload)
						else
							break
						end
					end
				end
			end
		end
	end
end

return usbmuxd
