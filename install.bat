@echo off
set CC=%cd%
cd ..\ant_release
git pull
cd %CC%
.\bin\msvc\release\lua.exe install.lua %*

if "%1" == "" (
    cd ..\ant_release
    git add .
    git commit -m "new" .
    git push
)
echo "pasue..."
pause > nil