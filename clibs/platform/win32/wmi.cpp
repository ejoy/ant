#include "wmi.h"

class ScopedBstr {
public:
	ScopedBstr() : bstr_(NULL) { }
	ScopedBstr(const std::wstring& bstr) : bstr_(SysAllocString(bstr.c_str())) { }
	~ScopedBstr() { SysFreeString(bstr_); }
	operator BSTR() const { return bstr_; }
protected:
	BSTR bstr_;
};

class ScopedVariant {
public:
	ScopedVariant() { var_.vt = VT_EMPTY; }
	~ScopedVariant() { ::VariantClear(&var_); }
	VARTYPE        type() const { return var_.vt; }
	const VARIANT* ptr()  const { return &var_; }
	VARIANT* Receive() { return &var_; }
protected:
	VARIANT var_;
};

wmi::wmi() {
	if (FAILED(CoInitializeEx(0, COINIT_MULTITHREADED))) {
		return;
	}
	Microsoft::WRL::ComPtr<IWbemLocator> locator;
	if (FAILED(CoCreateInstance(CLSID_WbemLocator, NULL, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&locator)))) {
		return;
	}
	Microsoft::WRL::ComPtr<IWbemServices> services;
	if (FAILED(locator->ConnectServer(BSTR(L"ROOT\\CIMV2"), NULL, NULL, NULL, 0, NULL, NULL, services.GetAddressOf()))) {
		return;
	}
	if (FAILED(CoSetProxyBlanket(services.Get(), RPC_C_AUTHN_WINNT, RPC_C_AUTHZ_NONE, NULL, RPC_C_AUTHN_LEVEL_CALL, RPC_C_IMP_LEVEL_IMPERSONATE, NULL, EOAC_NONE))) {
		return;
	}
	services_ = services;
}

wmi::object wmi::query(const std::wstring& query) {
	Microsoft::WRL::ComPtr<IEnumWbemClassObject> enumerator;
	if (FAILED(services_->ExecQuery(BSTR(L"WQL"), ScopedBstr(query), WBEM_FLAG_FORWARD_ONLY | WBEM_FLAG_RETURN_IMMEDIATELY, NULL, enumerator.GetAddressOf()))) {
		return object();
	}
	Microsoft::WRL::ComPtr<IWbemClassObject> class_object;
	ULONG items_returned;
	if (FAILED(enumerator->Next(WBEM_INFINITE, 1, class_object.GetAddressOf(), &items_returned))) {
		return object();
	}
	if (!items_returned) {
		return object();
	}
	return class_object;
}

std::wstring wmi::object::get_string(const wchar_t* property_name) {
	ScopedVariant prop_value;
	if (FAILED(object_->Get(property_name, 0, prop_value.Receive(), 0, 0)) || prop_value.type() != VT_BSTR) {
		return L"";
	}
	return std::wstring(V_BSTR(prop_value.ptr()));
}
