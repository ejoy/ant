#pragma once

#include <wrl/client.h>
#include <wbemidl.h>
#include <string>

class wmi {
public:
	class object {
	public:
		object() { }
		object(Microsoft::WRL::ComPtr<IWbemClassObject> object) : object_(object) { }
		std::wstring get_string(const wchar_t* property_name);
		operator bool() const { return !!object_; }
	protected:
		Microsoft::WRL::ComPtr<IWbemClassObject> object_;
	};

	wmi();
	operator bool() const { return !!services_; }
	object query(const std::wstring& query);

protected:
	Microsoft::WRL::ComPtr<IWbemServices> services_;
};
