@setlocal
@set TMPPERL=xp2json.pl
@if NOT EXIST %TMPPERL% goto ERR1
@set TMPCMD=
:RPT
@if "%~1x" == "x" goto GOTCMD
@set TMPCMD=%TMPCMD% %1
@shift
@goto RPT
:GOTCMD

perl -f %TMPPERL% %TMPCMD%

@goto END

:ERR1
@echo Error: Can NOT locate script %TMPPERL%! *** FIX ME ***
@goto END

:END
