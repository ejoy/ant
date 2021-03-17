
#ifndef __EFFEKSEER_DEFAULT_FILE_H__
#define __EFFEKSEER_DEFAULT_FILE_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include "Effekseer.Base.h"
#include "Effekseer.File.h"

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
/**
	@brief	標準のファイル読み込みクラス
*/

class DefaultFileReader : public FileReader
{
private:
	FILE* m_filePtr;

public:
	DefaultFileReader(FILE* filePtr);

	~DefaultFileReader();

	size_t Read(void* buffer, size_t size);

	void Seek(int position);

	int GetPosition();

	size_t GetLength();
};

class DefaultFileWriter : public FileWriter
{
private:
	FILE* m_filePtr;

public:
	DefaultFileWriter(FILE* filePtr);

	~DefaultFileWriter();

	size_t Write(const void* buffer, size_t size);

	void Flush();

	void Seek(int position);

	int GetPosition();

	size_t GetLength();
};

class DefaultFileInterface : public FileInterface
{
private:
public:
	FileReader* OpenRead(const char16_t* path);

	FileWriter* OpenWrite(const char16_t* path);
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#endif // __EFFEKSEER_DEFAULT_FILE_H__
