@echo off
REM Script amélioré pour diagnostiquer et relancer Flutter/Dart VM Service (Windows)

REM Aller à la racine du projet (un niveau au‑dessus du dossier scripts)
cd /d "%~dp0\.."

REM Vérifier que adb et flutter sont dans le PATH
where adb >nul 2>&1
if errorlevel 1 (
  echo ERREUR: adb introuvable dans le PATH. Ajouter platform-tools du SDK Android au PATH.
  pause
  exit /b 1
)
where flutter >nul 2>&1
if errorlevel 1 (
  echo ERREUR: flutter introuvable dans le PATH. Ajouter Flutter SDK au PATH.
  pause
  exit /b 1
)

echo --------------------------
echo Restarting adb server and removing old forwards...
echo --------------------------
adb kill-server
timeout /t 1 /nobreak >nul
adb start-server
timeout /t 1 /nobreak >nul
adb forward --remove-all 2>nul

echo.
echo --------------------------
echo Devices connected:
echo --------------------------
adb devices -l
echo.

REM Vérifier qu'il y a au moins un device/emulator
for /f "skip=1 tokens=1,2" %%a in ('adb devices') do (
  if "%%b"=="" (
    REM ligne vide ou en-tete
  ) else (
    set HAS_DEVICE=1
  )
)
if not defined HAS_DEVICE (
  echo AUCUN DEVICE DETECTE. Veuillez demarrer un emulateur ou connecter un appareil.
  pause
  exit /b 1
)

echo --------------------------
echo Cleaning Flutter project...
echo --------------------------
flutter clean
if errorlevel 1 (
  echo ERREUR: flutter clean a echoue.
  pause
  exit /b 1
)
flutter pub get

REM Préparer dossier de logs et timestamp safe pour nom de fichier
set ts=%DATE%_%TIME%
set ts=%ts::=-%
set ts=%ts:/=-%
set ts=%ts:.=-%
set ts=%ts: =_%

if not exist logs mkdir logs

echo.
echo --------------------------
echo Running flutter run (verbeux) and saving logs to logs\flutter_run_%ts%.log
echo --------------------------
flutter run -v > "logs\flutter_run_%ts%.log" 2>&1
if errorlevel 1 (
  echo.
  echo Flutter run a echoue. Recuperation de adb logcat...
  adb logcat -d > "logs\adb_log_%ts%.txt"
  echo Logs enregistres:
  echo  - logs\flutter_run_%ts%.log
  echo  - logs\adb_log_%ts%.txt
  echo.
  echo CONSEILS RAPIDES:
  echo  - Essayez: flutter run -v (executer manuellement pour voir la trace)
  echo  - Desactivez temporairement antivirus/pare-feu ou autorisez adb/IDE
  echo  - Redemarrer l'emulateur/device
  echo  - Mettre a jour platform-tools (adb) et Flutter SDK
  pause
  exit /b 1
)

echo.
echo Lancement reussi. Si le probleme persiste, consultez le fichier logs\flutter_run_%ts%.log
pause
