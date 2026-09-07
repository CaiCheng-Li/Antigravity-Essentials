@echo off
:: Set up the Antigravity CLI wrapper alias
:: This ensures that typing `agy` intercepts the command to our wrapper script.
doskey agy="%USERPROFILE%\agy.bat" $*
