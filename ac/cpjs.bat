@setlocal
@set SRCDIR=C:\OSGeo4W\apache\htdocs\map-test\ac
@set DSTDIR=F:\FG\map-test\ac

@for %%i in (%SRCDIR%\*.js) do @(call :COPYONE %%i)

@goto END

:COPYONE
@if "%~1x" == "x" goto :EOF
@set NAME=%~n1
@set DEST
@echo %NAME%
@set DEST=%DSTDIR%\%NAME%
@if NOT EXIST %DEST%\nul (
@md %DEST%
)
@copy %1 %DEST%
@goto :EOF

:END
