@setlocal
@echo Generate a new 'index' table...
@set TMPOPTS=-v -b -s

@REM add ignore.txt if it exists
@if EXIST ignore.txt (
@set TMPOPTS=%TMPOPTS% -X ignore.txt
)

@REM add description.csv if it exists
@if EXIST description.csv (
@set TMPOPTS=%TMPOPTS% -d description.csv
)

@set TMPOPTS=%TMPOPTS% -x temp*

:RPT
@if "%~1x" == "x" goto GOTCMD
@set TMPOPTS=%TMPOPTS% %1
@shift
@goto RPT

:GOTCMD

call genindex %TMPOPTS% .

@REM eof
