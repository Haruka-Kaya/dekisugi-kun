@echo off
"%~dp0dekisugi-lan-coordinator.exe" --host 0.0.0.0 --allow-lan
if errorlevel 1 pause
