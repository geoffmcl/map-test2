@setlocal
@set TMPEXE=testjson.exe
@set TMPERR=temperr.txt
@if NOT EXIST %TMPEXE% goto NOEXE
@if "%~1x" == "x" goto HELP

@set TMPCNT1=0
@set TMPCNT2=0
@set TMPCNT3=0

@for %%i in (%1) do @(call :ADDIT %%i)

@if "%TMPCNT1%x" == "0x" goto ERR1

@echo Using %1, found %TMPCNT1% files to check...
@echo *** CONTINUE? *** Only Ctrl+C aborts...
@pause

@if EXIST %TMPERR% del %TMPERR% >nul

@for %%i in (%1) do @(call :CHKIT %%i)

@if "%TMPCNT3%x" == "0x" (
@echo Appears ALL passed...
) else (
@echo Note %TMPCNT3% FAILED!
@type %TMPERR%
@echo Check %TMPERR% file for list of %TMPCNT3% FAILED!
)

@goto END

:ADDIT
@if "%~1x" == "x" goto :EOF
@if NOT EXIST %1 goto :EOF
@set /a TMPCNT1+=1
@goto :EOF

:CHKIT
@if "%~1x" == "x" goto :EOF
@if NOT EXIST %1 goto :EOF
@set /a TMPCNT2+=1
@echo %TMPCNT2% of %TMPCNT1%: Checking %1
@%TMPEXE% --json-checker %1
@if ERRORLEVEL 1 goto FAILED
@goto :EOF

:FAILED
@echo Note %1 FAILED!
@echo %1 >>%TMPERR%
@set /a TMPCNT3+=1
@goto :EOF

:NOEXE
@echo Error: Can NOT locate %TMPEXE%! *** FIX ME ***
@goto END


:HELP
@echo Enter file mask for json files to check...
@goto END

:ERR1
@echo Using mask %1 found NO files to check...
@goto END

:END
