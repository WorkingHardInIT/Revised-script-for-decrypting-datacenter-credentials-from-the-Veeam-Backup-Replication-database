param (
    [string]$Username,
    [switch]$NoExport
)

Function DecryptVeeamEncryptedPasswords-V2 {
[CmdletBinding()]
param (
    [string]$Username       # Optional: filter for a specific user
    #[switch]$NoExport        # Optional: skip writing to file
)

if (-not $PSBoundParameters.ContainsKey('Username')) {
        Write-Host "ℹ️ Username parameter was not passed." -ForegroundColor DarkGray
        #DecryptVeeamEncryptedPasswords-V2
    }
    elseif ([string]::IsNullOrWhiteSpace($Username)) {
        Write-Host "❌ Username was passed but is null, empty, or only whitespace." -ForegroundColor red
        return
    }
    else {
        Write-Host "✅ Username was passed and is: '$Username'" -ForegroundColor green
        #DecryptVeeamEncryptedPasswords-V2 -Username $Username
    }

Write-Host "🔧 NoExport flag: $NoExport" -ForegroundColor DarkGray

# --- Metadata and output file setup ---
$exportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$executingUser = $env:USERNAME
$vbrServerName = $env:COMPUTERNAME
$outputFile = "$env:USERPROFILE\Desktop\Veeam_Credentials.txt"

if (-not $NoExport) {
    @"
Veeam Credentials Export
Date: $exportDate
Executed by: $executingUser
VBR Server: $vbrServerName
----------------------------------------
"@ | Out-File -FilePath $outputFile -Encoding UTF8
}

# --- Load required .NET assembly ---
try {
    Add-Type -AssemblyName System.Security
}
catch {
    Write-Host "❌ Failed to load System.Security assembly: $_" -ForegroundColor Red
    exit
}

# --- Read registry configuration ---
try {
    $DBConfig = Get-ItemProperty -Path "HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication\DatabaseConfigurations"
    $DBType = $DBConfig.SqlActiveConfiguration
    $saltBase = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication\Data").EncryptionSalt
}
catch {
    Write-Host "❌ Failed to read registry configuration: $_" -ForegroundColor Red
    exit
}

function Get-VeeamPasswordFormat {
    param ($password)
    switch -Regex ($password) {
        "^A" { return "v12 and lower" }
        "^V" { return "v12.1 and up  (with encryption salt)" }
        default { return "Unknown" }
    }
}

function Decrypt-V11Password {
    param ($context)
    try {
        $data = [Convert]::FromBase64String($context)
        $raw = [System.Security.Cryptography.ProtectedData]::Unprotect($data, $null, 'LocalMachine')
        return [System.Text.Encoding]::UTF8.GetString($raw)
    }
    catch {
        throw "v12 and lower type password decryption failed: $_"
    }
}

function Decrypt-V12Password {
    param ($context, $saltBase)
    try {
        $salt = [Convert]::FromBase64String($saltBase)
        $data = [Convert]::FromBase64String($context)
        $hex = ($data | ForEach-Object { "{0:x2}" -f $_ }) -join ""
        $hex = $hex.Substring(74)
        $bytes = [byte[]]::new($hex.Length / 2)
        for ($i = 0; $i -lt $hex.Length; $i += 2) {
            $bytes[$i / 2] = [Convert]::ToByte($hex.Substring($i, 2), 16)
        }
        $raw = [System.Security.Cryptography.ProtectedData]::Unprotect($bytes, $salt, 'LocalMachine')
        return [System.Text.Encoding]::UTF8.GetString($raw)
    }
    catch {
        throw "v12.1 and up (with encryption salt) password decryption failed: $_"
    }
}

function Get-MssqlCredentials {
    try {
        $SQLConfig = Get-ItemProperty -Path "HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication\DatabaseConfigurations\MsSql"
        $SQLConnection = "$($SQLConfig.SqlServerName)\$($SQLConfig.SqlInstanceName)"
        $SQLDB = $SQLConfig.SqlDatabaseName
        $query = "SELECT user_name,password FROM dbo.Credentials"

        $conn = New-Object System.Data.SqlClient.SqlConnection
        $conn.ConnectionString = "server='$SQLConnection';database='$SQLDB';integrated security=true"
        $conn.Open()
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $query
        $dt = New-Object System.Data.DataTable
        $dt.Load($cmd.ExecuteReader())
        return $dt
    }
    catch {
        Write-Host "❌ MSSQL connection failed: $_" -ForegroundColor Red
        return @()
    }
}

function Get-PostgreCredentials {
    try {
        $PGConfig = Get-ItemProperty -Path "HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication\DatabaseConfigurations\PostgreSql"
        $PGHost = $PGConfig.Host
        $PGPort = $PGConfig.Port
        $PGDB = $PGConfig.Database
        $PGUser = $PGConfig.UserName

        $PGPass = Read-Host -Prompt "Enter PostgreSQL password for user '$PGUser'" -AsSecureString
        $PGPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($PGPass))
        $query = "SELECT user_name,password FROM public.Credentials"

        try {
            Add-Type -AssemblyName "Npgsql"
            $connStr = "Host=$PGHost;Port=$PGPort;Username=$PGUser;Password=$PGPlain;Database=$PGDB"
            $conn = New-Object Npgsql.NpgsqlConnection($connStr)
        }
        catch {
            Write-Host "⚠️ Npgsql not available. Falling back to ODBC..." -ForegroundColor Yellow
            $connStr = "Driver={PostgreSQL Unicode};Server=$PGHost;Port=$PGPort;Database=$PGDB;Uid=$PGUser;Pwd=$PGPlain;"
            $conn = New-Object System.Data.Odbc.OdbcConnection
        }

        $conn.ConnectionString = $connStr
        $conn.Open()
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $query
        $dt = New-Object System.Data.DataTable
        $dt.Load($cmd.ExecuteReader())
        return $dt
    }
    catch {
        Write-Host "❌ PostgreSQL connection failed: $_" -ForegroundColor Red
        return @()
    }
}

$accounts = if ($DBType -eq "Mssql") { Get-MssqlCredentials } else { Get-PostgreCredentials }

$userCount = 0

foreach ($account in $accounts) {
    $accountUsername = "$($account.user_name)"
    $context = "$($account.password)"

    # Skip if username was provided and doesn't match this one
    if ($PSBoundParameters.ContainsKey('Username') -and -not [string]::IsNullOrWhiteSpace($Username)) {
        if ($accountUsername.ToLower() -ne $Username.Trim().ToLower()) {
            continue
        }
    }
    elseif ($PSBoundParameters.ContainsKey('Username') -and [string]::IsNullOrWhiteSpace($Username)) {
        # Username explicitly passed but it's empty/whitespace -> skip all
        continue
    }

    if (-not $accountUsername) { continue }

    $userCount++
    Write-Host "`n--- User #$userCount ---" -ForegroundColor Gray

    if ([string]::IsNullOrWhiteSpace($context)) {
        Write-Host "🔍 Username: $accountUsername ⚠️ No password stored." -ForegroundColor DarkYellow
        $entry = @"
User #$userCount
Username   : $accountUsername
Encrypted password  : [none]
Decrypted password  : [none]
**************************************
"@
        if (-not $NoExport) {
            Add-Content -Path $outputFile -Value $entry
        }
        continue
    }

    $format = Get-VeeamPasswordFormat $context
    Write-Host "🔍 Username: $accountUsername 🔐 Format: $format" -ForegroundColor Cyan
    Write-Host "   🔒 Encrypted password: $context" -ForegroundColor Yellow

    try {
        $decrypted = switch ($format) {
            "v12 and lower" {
                Decrypt-V11Password $context
            }
            "v12.1 and up  (with encryption salt)" {
                Decrypt-V12Password $context $saltBase
            }
            default {
                throw "Unknown format"
            }
        }

        Write-Host "   ✅ Decrypted password: $decrypted" -ForegroundColor Green
        $entry = @"
User #$userCount
Username   : $accountUsername
Encrypted password  : $context
Decrypted password  : $decrypted
**************************************
"@
    }
    catch {
        Write-Host "   ❌ Failed to decrypt password: $_" -ForegroundColor Red
        $entry = @"
User #$userCount
Username   : $accountUsername
Encrypted password  : $context
Decrypted password  : [decryption failed]
**************************************
"@
    }

    if (-not $NoExport) {
        Add-Content -Path $outputFile -Value $entry
    }
}

if (-not [string]::IsNullOrWhiteSpace($Username) -and $userCount -eq 0) {
    Write-Host "`n⚠️ No credentials found for user '$Username'" -ForegroundColor Yellow
}

if (-not $NoExport) {
    Write-Host "`n📁 Export complete: $outputFile" -ForegroundColor Magenta
}
else {
    Write-Host "`n📤 Export skipped (NoExport flag used)." -ForegroundColor Magenta
}
}

# 🧪 Run the function
if ($PSBoundParameters.ContainsKey('Username')) {
    DecryptVeeamEncryptedPasswords-V2 -Username $Username
} else {
    DecryptVeeamEncryptedPasswords-V2
}
if ($Host.Name -eq 'ConsoleHost') {
    Write-Host "`nPress Enter to exit..."
    [void][System.Console]::ReadLine()
}
