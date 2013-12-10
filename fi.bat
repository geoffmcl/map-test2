@setlocal
@set TMPFND=%1
@if "%TMPFND%x" == "x" goto HELP
@shift
@set TMPCMD=
:RPT
@if "%~1x" == "x" goto GOTCMD
@set TMPCMD=%TMPCMD% %1
@shift
@goto RPT
:GOTCMD

fa4 "%TMPFND%" -x::: -x:OpenLayers-2.12 * -r -b- %TMPCMD%

@goto END

:HELP
@echo Enter the word to find...
:END

