@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "ROOT_DIR=%SCRIPT_DIR%.."
set "CONFIG_FILE=%ROOT_DIR%\config.json"

set "QUERY="
set "N_OVERRIDE="
set "CATEGORY_OVERRIDE="
set "API_KEY_OVERRIDE="
set "BASE_URL_OVERRIDE="
set "TIMEOUT_MS_OVERRIDE="
set "DRY_RUN=0"
set "INSECURE=0"

:parse_args
if "%~1"=="" goto args_done

if /I "%~1"=="--n" (
  if "%~2"=="" goto arg_error
  set "N_OVERRIDE=%~2"
  shift
  shift
  goto parse_args
)

if /I "%~1"=="--category" (
  if "%~2"=="" goto arg_error
  set "CATEGORY_OVERRIDE=%~2"
  shift
  shift
  goto parse_args
)

if /I "%~1"=="--api-key" (
  if "%~2"=="" goto arg_error
  set "API_KEY_OVERRIDE=%~2"
  shift
  shift
  goto parse_args
)

if /I "%~1"=="--base-url" (
  if "%~2"=="" goto arg_error
  set "BASE_URL_OVERRIDE=%~2"
  shift
  shift
  goto parse_args
)

if /I "%~1"=="--timeout-ms" (
  if "%~2"=="" goto arg_error
  set "TIMEOUT_MS_OVERRIDE=%~2"
  shift
  shift
  goto parse_args
)

if /I "%~1"=="--dry-run" (
  set "DRY_RUN=1"
  shift
  goto parse_args
)

if /I "%~1"=="--insecure" (
  set "INSECURE=1"
  shift
  goto parse_args
)

if /I "%~1"=="--help" goto usage_ok
if /I "%~1"=="-h" goto usage_ok

if defined QUERY (
  set "QUERY=!QUERY! %~1"
) else (
  set "QUERY=%~1"
)
shift
goto parse_args

:args_done
if not defined QUERY goto usage_err

where curl >nul 2>nul
if errorlevel 1 (
  echo Error: curl not found in PATH.
  exit /b 127
)

set "CFG_API_KEY="
set "CFG_BASE_URL="
set "CFG_DEFAULT_N="
set "CFG_DEFAULT_CATEGORY="
set "CFG_TIMEOUT_MS="

if exist "%CONFIG_FILE%" (
  for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "$c=Get-Content -Raw '%CONFIG_FILE%' | ConvertFrom-Json; if($c.api_key){$c.api_key}"`) do set "CFG_API_KEY=%%A"
  for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "$c=Get-Content -Raw '%CONFIG_FILE%' | ConvertFrom-Json; if($c.base_url){$c.base_url}"`) do set "CFG_BASE_URL=%%A"
  for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "$c=Get-Content -Raw '%CONFIG_FILE%' | ConvertFrom-Json; if($c.default_n){$c.default_n}"`) do set "CFG_DEFAULT_N=%%A"
  for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "$c=Get-Content -Raw '%CONFIG_FILE%' | ConvertFrom-Json; if($c.default_category -ne $null){$c.default_category}"`) do set "CFG_DEFAULT_CATEGORY=%%A"
  for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "$c=Get-Content -Raw '%CONFIG_FILE%' | ConvertFrom-Json; if($c.timeout_ms){$c.timeout_ms}"`) do set "CFG_TIMEOUT_MS=%%A"
)

if defined API_KEY_OVERRIDE (
  set "API_KEY=%API_KEY_OVERRIDE%"
) else if defined STEPFUN_API_KEY (
  set "API_KEY=%STEPFUN_API_KEY%"
) else (
  set "API_KEY=%CFG_API_KEY%"
)

if defined BASE_URL_OVERRIDE (
  set "BASE_URL=%BASE_URL_OVERRIDE%"
) else if defined CFG_BASE_URL (
  set "BASE_URL=%CFG_BASE_URL%"
) else (
  set "BASE_URL=https://api.stepfun.com"
)

if defined N_OVERRIDE (
  set "N=%N_OVERRIDE%"
) else if defined CFG_DEFAULT_N (
  set "N=%CFG_DEFAULT_N%"
) else (
  set "N=10"
)

if defined CATEGORY_OVERRIDE (
  set "CATEGORY=%CATEGORY_OVERRIDE%"
) else (
  set "CATEGORY=%CFG_DEFAULT_CATEGORY%"
)

if defined TIMEOUT_MS_OVERRIDE (
  set "TIMEOUT_MS=%TIMEOUT_MS_OVERRIDE%"
) else if defined CFG_TIMEOUT_MS (
  set "TIMEOUT_MS=%CFG_TIMEOUT_MS%"
) else (
  set "TIMEOUT_MS=30000"
)

if "%DRY_RUN%"=="0" if not defined API_KEY (
  echo Error: API key is missing. Set config.json api_key or use --api-key/STEPFUN_API_KEY.
  exit /b 2
)

echo(%N%| findstr /r "^[0-9][0-9]*$" >nul
if errorlevel 1 (
  echo Error: n must be a number, got %N%
  exit /b 2
)

echo(%TIMEOUT_MS%| findstr /r "^[0-9][0-9]*$" >nul
if errorlevel 1 (
  echo Error: timeout-ms must be a number, got %TIMEOUT_MS%
  exit /b 2
)

if defined CATEGORY call :validate_category "%CATEGORY%"
if errorlevel 1 exit /b %errorlevel%

for /f %%A in ('powershell -NoProfile -Command "[math]::Ceiling(%TIMEOUT_MS%/1000)"') do set "TIMEOUT_SEC=%%A"
if not defined TIMEOUT_SEC set "TIMEOUT_SEC=30"

set "ENDPOINT=%BASE_URL%"
if not "%ENDPOINT:~-1%"=="/" set "ENDPOINT=%ENDPOINT%/"
set "ENDPOINT=%ENDPOINT%v1/search"

set "ESC_QUERY=%QUERY%"
set "ESC_QUERY=%ESC_QUERY:\"=\\\"%"
set "PAYLOAD={\"query\":\"%ESC_QUERY%\",\"n\":%N%"
if defined CATEGORY set "PAYLOAD=%PAYLOAD%,\"category\":\"%CATEGORY%\""
set "PAYLOAD=%PAYLOAD%}"

if "%DRY_RUN%"=="1" (
  echo [dry-run] endpoint: %ENDPOINT%
  echo [dry-run] payload: %PAYLOAD%
  exit /b 0
)

set "CURL_TLS_FLAG="
if "%INSECURE%"=="1" set "CURL_TLS_FLAG=-k"

set "TMP_FILE=%TEMP%\step-web-search-%RANDOM%%RANDOM%.json"
set "TMP_ERR=%TEMP%\step-web-search-%RANDOM%%RANDOM%.err"
set "TMP_CODE=%TEMP%\step-web-search-%RANDOM%%RANDOM%.code"
curl %CURL_TLS_FLAG% -sS -m %TIMEOUT_SEC% -o "%TMP_FILE%" -w "%%{http_code}" -X POST "%ENDPOINT%" -H "Content-Type: application/json" -H "Authorization: Bearer %API_KEY%" -d "%PAYLOAD%" 1>"%TMP_CODE%" 2>"%TMP_ERR%"
set "CURL_EXIT=%ERRORLEVEL%"

if not "%CURL_EXIT%"=="0" (
  if exist "%TMP_ERR%" type "%TMP_ERR%"
  findstr /I /C:"AcquireCredentialsHandle failed" /C:"SEC_E_NO_CREDENTIALS" "%TMP_ERR%" >nul 2>nul
  if not errorlevel 1 (
    echo Hint: this Windows TLS environment cannot establish HTTPS for curl.
    echo Fallback: use Node.js runner directly:
    echo   node "%~dp0step-web-search.mjs" "%QUERY%" --n %N% --category %CATEGORY%
  )
  if exist "%TMP_FILE%" del /q "%TMP_FILE%" >nul 2>nul
  if exist "%TMP_ERR%" del /q "%TMP_ERR%" >nul 2>nul
  if exist "%TMP_CODE%" del /q "%TMP_CODE%" >nul 2>nul
  exit /b 1
)

set /p HTTP_CODE=<"%TMP_CODE%"
if not defined HTTP_CODE (
  echo Error: request failed.
  if exist "%TMP_FILE%" del /q "%TMP_FILE%" >nul 2>nul
  if exist "%TMP_ERR%" del /q "%TMP_ERR%" >nul 2>nul
  if exist "%TMP_CODE%" del /q "%TMP_CODE%" >nul 2>nul
  exit /b 1
)

if %HTTP_CODE% LSS 200 (
  echo HTTP %HTTP_CODE%
  type "%TMP_FILE%"
  del /q "%TMP_FILE%" >nul 2>nul
  if exist "%TMP_ERR%" del /q "%TMP_ERR%" >nul 2>nul
  if exist "%TMP_CODE%" del /q "%TMP_CODE%" >nul 2>nul
  exit /b 1
)

if %HTTP_CODE% GEQ 300 (
  echo HTTP %HTTP_CODE%
  type "%TMP_FILE%"
  del /q "%TMP_FILE%" >nul 2>nul
  if exist "%TMP_ERR%" del /q "%TMP_ERR%" >nul 2>nul
  if exist "%TMP_CODE%" del /q "%TMP_CODE%" >nul 2>nul
  exit /b 1
)

type "%TMP_FILE%"
del /q "%TMP_FILE%" >nul 2>nul
if exist "%TMP_ERR%" del /q "%TMP_ERR%" >nul 2>nul
if exist "%TMP_CODE%" del /q "%TMP_CODE%" >nul 2>nul
exit /b 0

:arg_error
echo Error: missing argument value.
exit /b 2

:usage_err
echo Usage:
echo   scripts\step-web-search.cmd "^<query^>" [--n ^<number^>] [--category ^<value^>] [--api-key ^<key^>] [--base-url ^<url^>] [--timeout-ms ^<ms^>] [--dry-run] [--insecure] [--help]
exit /b 2

:usage_ok
echo Usage:
echo   scripts\step-web-search.cmd "^<query^>" [--n ^<number^>] [--category ^<value^>] [--api-key ^<key^>] [--base-url ^<url^>] [--timeout-ms ^<ms^>] [--dry-run] [--insecure] [--help]
exit /b 0

:validate_category
if /I "%~1"=="programming" exit /b 0
if /I "%~1"=="research" exit /b 0
if /I "%~1"=="gov" exit /b 0
if /I "%~1"=="business" exit /b 0
echo Error: category must be one of: programming, research, gov, business
exit /b 2