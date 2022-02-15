@echo off
set ant=%~dp0..\..\
for %%i in ("%ant%") do set "ant=%%~fi"
cd %ant% && .\bin\msvc\debug\lua.exe tools\rmlviewer\main.lua %~f1
