#if defined(__APPLE__)
#import <Foundation/Foundation.h>
#include "efkMat.Utils.h"

namespace EffekseerMaterial
{

std::string NFCtoNFD(const std::string& v)
{
	NSString* nfc = [NSString stringWithCString:v.c_str() encoding:NSUTF8StringEncoding];
	NSString* nfd = [nfc decomposedStringWithCanonicalMapping];
	std::string res = [nfd UTF8String];
	[nfd release];
	[nfc release];
	return res;
}

std::string NFDtoNFC(const std::string& v)
{
	NSString* nfd = [NSString stringWithCString:v.c_str() encoding:NSUTF8StringEncoding];
	NSString* nfc = [nfd precomposedStringWithCanonicalMapping];
	std::string res = [nfc UTF8String];
	[nfd release];
	return res;
}

} // namespace EffekseerMaterial
#endif
