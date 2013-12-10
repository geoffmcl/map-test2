@setlocal
@if "%~1x" == "x" goto HELP
@set TMPCMD=
@set TMPCNT=0
:RPT
@if "%~1x" == "x" goto GOTCMD
@set TMPCMD=%TMPCMD% %1
@set /A TMPCNT+=1
@shift
@goto RPT
:GOTCMD
@echo Generate %TMPCNT% new json files for %TMPCMD%

call xp2json %TMPCMD%


@goto END

:HELP
@echo Give a list of airport ICAO to generate...
:END
