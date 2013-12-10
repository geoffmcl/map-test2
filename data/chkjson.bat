@setlocal
@set TMPFIL=apt1000-icao.csv
@echo Check there is a json file for each ICAO in %TMPFIL%
@if NOT EXIST %TMPFIL% goto ERR1

@set TMPCNT=0
@set TMPCNT1=0
@set TMPCNT2=0

@for /F "tokens=1,*skip=1delims=," %%i in (%TMPFIL%) do @(call :CHKME %%i)

@echo Processed %TMPCNT% lines... seeking %TMPCNT1% files, found %TMPCN2%

@goto END

:CHKME
@if "%~1x" == "x" goto :EOF
@set /A TMPCNT+=1
@set TMPF=%1.json
@if %TMPCNT% LSS 2 goto :EOF
@set /A TMPCNT1+=1
@if NOT EXIST %TMPF% goto NOFIL
@set /A TMPCNT2+=1
@goto :EOF
:NOFIL
@echo Failed to find %TMPF%!
@goto :EOF


:ERR1
@echo Error: Can NOT locae file %TMPFIL%! FIX ME!!!
@goto END

:END
