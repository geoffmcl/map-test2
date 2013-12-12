@setlocal
@set TMPEXE=testjson.exe
@if NOT EXIST %TMPEXE% goto ERR1
@if "%~1x" == "x" goto HELP
@if NOT EXIST %1 goto NOFIL

%TMPEXE% --json-checker %1
@if ERRORLEVEL 1 goto BADJSON
@echo %TMPEXE% accepts %1 as valid json...

@goto END

:BADJSON
@echo %TMPEXE% reports %1 as 'bad' json...
@goto END

:HELP
@echo Must give NAME of file to check!
@goto END


:NOFIL
@echo Error: Can NOT locate file %1! Check name and location...
@goto END

:ERR1
@echo Error: Can NOT find EXE %TMPEXE%! *** FIX ME ***
:END

