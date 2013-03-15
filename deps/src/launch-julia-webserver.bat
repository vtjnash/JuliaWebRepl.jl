@echo off
@rem when installed, JULIA_HOME and THIS_SCRIPT will be exported by the previous line
pushd %cd%
set PATH=PATH;%JULIA_HOME%
setlocal enableextensions enabledelayedexpansion
call %JULIA_HOME%prepare-julia-env.bat %*

pushd %cd%
cd %THIS_SCRIPT%..\sbin
start /b nginx -c %THIS_SCRIPT%..\etc\nginx.conf
popd

echo Connect to http://localhost:2000/ for the web REPL.
echo Press Ctrl-C to quit, then answer N to prompt
start /b http://localhost:2000/
cd %THIS_SCRIPT%..\bin
call julia-release-webserver.exe -p 2001 %JULIA_HOME%julia-release-basic.exe

echo Killing nginx... (this can take a few seconds)
for /F "delims=" %%a in (%THIS_SCRIPT%../sbin/logs/nginx.pid) do taskkill /f /t /pid %%a
sleep 1
echo Exiting...
endlocal
popd
pause
