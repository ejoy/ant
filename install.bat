@echo off
cd ..\ant_release
git pull
cd ..\ant
.\bin\msvc\Release\lua.exe install.lua %*
cd ..\ant_release
git add .
git commit -m "new" .
git push