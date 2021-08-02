/*
 * This source file is part of RmlUi, the HTML/CSS Interface Middleware
 *
 * For the latest information, see http://github.com/mikke89/RmlUi
 *
 * Copyright (c) 2008-2010 CodePoint Ltd, Shift Technology Ltd
 * Copyright (c) 2019 The RmlUi Team, and contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#ifndef RMLUI_CORE_URL_H
#define RMLUI_CORE_URL_H

#include "Header.h"
#include "Types.h"

namespace Rml {

/**
	@author Peter Curry
 */

class RMLUICORE_API URL
{
public:
	/// Constructs an empty URL.
	URL();
	/// Constructs a new URL from the given string.
	URL(const std::string& url);
	/// Constructs a new URL from the given string. A little more scripting
	/// engine friendly.
	URL(const char* url);
	/// Destroys the URL.
	~URL();

	/// Assigns a new URL to the object. This will return false if the URL
	/// is malformed.
	bool SetURL(const std::string& url);
	/// Returns the entire URL.
	const std::string& GetURL() const;

	/// Sets the URL's protocol.
	bool SetProtocol(const std::string& protocol);
	/// Returns the protocol this URL is utilising.
	const std::string& GetProtocol() const;

	/// Sets the URL's login
	bool SetLogin( const std::string& login );
	/// Returns the URL's login
	const std::string& GetLogin() const;

	/// Sets the URL's password
	bool SetPassword( const std::string& password );
	/// Returns the URL's password
	const std::string& GetPassword() const;

	/// Sets the URL's host.
	bool SetHost(const std::string& host);
	/// Returns the URL's host.
	const std::string& GetHost() const;

	/// Sets the URL's port number.
	bool SetPort(int port);
	/// Returns the URL's port number.
	int GetPort() const;

	/// Sets the URL's path.
	bool SetPath(const std::string& path);
	/// Prefixes the URL's existing path with the given prefix.
	bool PrefixPath(const std::string& prefix);
	/// Returns the URL's path.
	const std::string& GetPath() const;

	/// Sets the URL's file name.
	bool SetFileName(const std::string& file_name);
	/// Returns the URL's file name.
	const std::string& GetFileName() const;

	/// Sets the URL's file extension.
	bool SetExtension(const std::string& extension);
	/// Returns the URL's file extension.
	const std::string& GetExtension() const;
	
	/// Access the url parameters
	typedef std::unordered_map< std::string, std::string > Parameters;
	const Parameters& GetParameters() const;
	void SetParameter(const std::string& name, const std::string& value);
	void SetParameters( const Parameters& parameters );
	void ClearParameters();
	
	/// Returns the URL's path, file name and extension.
	std::string GetPathedFileName() const;
	/// Builds and returns a url query string ( key=value&key2=value2 )		
	std::string GetQueryString() const;

	/// Less-than operator for use as a key in STL containers.
	bool operator<(const URL& rhs) const;

	/// Since URLs often contain characters outside the ASCII set, 
	/// the URL has to be converted into a valid ASCII format and back.
	static std::string UrlEncode(const std::string &value);
	static std::string UrlDecode(const std::string &value);

private:
	void ConstructURL() const;

	/// Portable character check (remember EBCDIC). Do not use isalnum() because
	/// its behavior is altered by the current locale.
	/// See http://tools.ietf.org/html/rfc3986#section-2.3
	/// (copied from libcurl sources)
	static bool IsUnreservedChar(const char c);

	mutable std::string url;
	std::string protocol;
	std::string login;
	std::string password;
	std::string host;		
	std::string path;
	std::string file_name;
	std::string extension;

	Parameters parameters;

	int port;
	mutable int url_dirty;
};

} // namespace Rml
#endif
