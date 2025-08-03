# 🔐 Decrypt Veeam Backup & Replication Stored Credentials

This PowerShell script retrieves and decrypts credentials stored in a Veeam Backup & Replication (VBR) configuration database. It supports both **MSSQL** and **PostgreSQL** backends and handles credentials encrypted in **v12** as well as **v12.1 and later**, which use an **encryption salt**. It is based on information found in the Veeam KB article "How to Recover Account Credentials From the Veeam Backup & Replication Database" (https://www.veeam.com/kb4349). Also, see my blog about this script: 

## ✅ Features

- 🔎 Retrieves stored credentials from MSSQL or PostgreSQL database  
- 🔐 Detects and supports both:  
  - **v12 and earlier**: base64 + DPAPI-encrypted strings starting with `A`  
  - **v12.1+**: base64 + encryption salt, prefixed with `V`  
- 🧂 Automatically retrieves encryption salt from the registry  
- 🧾 Optional filtering by username (`-Username`)  
- 💾 Optional suppression of file export (`-NoExport`)  
- 🧵 Single-pass logic (no recursion or redundant processing)  
- 💡 Informative output with emoji + color coding  
- 📋 Clean export formatting (if enabled)

## 🧠 Parameter Reference

### `-Username` (optional)

- If omitted, the script processes all available credentials.
- If provided, only credentials for the specified user are processed.
- If empty or whitespace, the script halts with a warning.

### `-NoExport` (optional)

- If used, the script does not export results to a file.
- If not specified, results are written to a file:

`%USERPROFILE%\Desktop\Veeam_Credentials.txt`

## 🧂 Info needed to access and query the database
In Veeam Backup & Replication, the database info lives in the registry

- The Veeam database info in the registry lives here and is retrieved by the script as needed:
`Computer\HKEY_LOCAL_MACHINE\SOFTWARE\Veeam\Veeam Backup and Replication\DatabaseConfigurations\`
<img width="600" height="400" alt="image" src="https://github.com/user-attachments/assets/f1a55879-b2fd-453d-b17c-550989709d9c" />


## 🧂 Encryption Salt Handling

In Veeam Backup & Replication v12.1 and later, encrypted passwords use an additional salt to protect the data.

This script:

- Automatically retrieves the encryption salt from the registry:

`HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication\Data`
<img width="700" height="322" alt="image" src="https://github.com/user-attachments/assets/5a3a7bd3-af35-4e89-9290-a1a9426c6080" />


- Applies the salt when decrypting passwords that begin with `V` (v12.1+ format)

No manual configuration is needed.

## 📄 Example Usage

```powershell
# Decrypt all credentials and export to Desktop
.\DecryptVeeamEncryptedPasswords.ps1

# Decrypt a specific user and export results
.\DecryptVeeamEncryptedPasswords.ps1 -Username 'DOMAIN\veeamservice'

# Decrypt a specific user without exporting
.\DecryptVeeamEncryptedPasswords.ps1 -Username 'DOMAIN\dbadmin' -NoExport
```

## 📦 Sample Output

```
--- User #1 ---
🔍 Username: DOMAIN\backupadmin 🔐 Format: v12.1 and up  (with encryption salt)
   🔒 Encrypted password: V2lZQU1Da...==
   ✅ Decrypted password: P@ssword123!
```

If a password is missing or can't be decrypted:

```
--- User #2 ---
🔍 Username: DOMAIN\tempuser ⚠️ No password stored.
```

If `-Username` is specified but no match is found:

```
⚠️ No credentials found for user 'DOMAIN\ghostuser'
```

## 🛠 Requirements

- PowerShell 5.1 or PowerShell Core (7+)
- Local admin privileges
- Access to the Veeam registry hive
- For PostgreSQL: Npgsql.dll or ODBC PostgreSQL driver

## ❗ Notes

- The script does not modify any data or credentials.
- Passwords are decrypted locally using Windows DPAPI.
- All sensitive data is handled in memory only unless you choose to export.
- The script includes fallback to ODBC if the Npgsql .NET assembly is not available.

## 📁 Output File Format

If export is enabled (default behavior), the output file will contain entries like:

```
Veeam Credentials Export
Date: 2025-08-03 14:23:57
Executed by: administrator
VBR Server: VEEAM-BR01
----------------------------------------

User #1
Username           : DOMAIN\svc.veeam
Encrypted password : AASD8fjs9asdf...
Decrypted password : MySecureP@ss!
**************************************

User #2
Username           : DOMAIN\testuser
Encrypted password : VzdsSDFKKSDS...
Decrypted password : SuperStrongPassword!
**************************************
```

## 🧪 Testing

You can run the script directly in PowerShell:

```powershell
.\DecryptVeeamEncryptedPasswords.ps1 -Username 'veeamadmin' -NoExport
```

To prevent the script from closing immediately (when run interactively), it will pause if executed in the console host.

## 📣 Credits

Script maintained by [WorkingHardInIT](https://github.com/WorkingHardInIT)  
Contributions welcome!
