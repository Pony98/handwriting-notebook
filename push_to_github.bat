@echo off
SET GIT_EXE="C:\src\flutter\bin\mingit\cmd\git.exe"
echo Pushing Handwriting Notebook to https://github.com/Pony98/handwriting-notebook.git ...
%GIT_EXE% remote remove origin 2>nul
%GIT_EXE% remote add origin https://github.com/Pony98/handwriting-notebook.git
%GIT_EXE% push -u origin main
echo.
echo Done! Now open: https://github.com/Pony98/handwriting-notebook/actions
pause
