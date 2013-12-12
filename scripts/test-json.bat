@setlocal
@set TMPPERL=test-json.pl
@if NOT EXIST %TMPPERL% goto ERR1
@set TMPCMD=
:RPT
@if "%~1x" == "x" goto GOTCMD
@set TMPCMD=%TMPCMD% %1
@shift
@goto RPT
:GOTCMD

perl -f %TMPPERL% %TMPCMD%
@if ERRORLEVEL 1 goto BADJSON
@echo %TMPPERL% reports %1 as 'valid' json
@goto END

:BADJSON
@echo %TMPPERL% reports %1 as 'bad' json
@goto END


:ERR1
@echo Error: Can NOT find script %TMPPERL%! *** FIX ME ***
:END

