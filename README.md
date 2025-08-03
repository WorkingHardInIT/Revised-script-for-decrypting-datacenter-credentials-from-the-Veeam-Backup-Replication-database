# Revised-script-for-decrypting-datacenter-credentials-from-the-Veeam-Backup-Replication-database
# 🔐 Veeam Credentials Export Script

This PowerShell script extracts and decrypts stored credentials from **Veeam Backup & Replication** configuration. It supports both **MSSQL** and **PostgreSQL** backends and handles multiple Veeam password formats (v12 and earlier, v12.1+ with encryption salt).

---

## 📦 Features

- ✅ Supports **VBR v10 through v12.3+** and decrypts Veeam credentials from registry and database  
- 👤 Per-user counters and clean output formatting  
- 🗄️ Supports **MSSQL** and **PostgreSQL** configurations  
- 🔐 Handles multiple password formats:  
  - `v12 and lower`  
  - `v12.1 and up (with encryption salt)`  
- 🔍 Optional filtering by username  
- 📁 Optional export to file (`Veeam_Credentials.txt` on Desktop)  
- 🛡️ Graceful error handling and informative console output  

---

## 🚀 Usage

```powershell
.\Export-VeeamCredentials.ps1 [-Username <string>] [-NoExport]
```

### Parameters

| Parameter   | Type     | Description                                                                 |
|-------------|----------|-----------------------------------------------------------------------------|
| `Username`  | `string` | (Optional) Filter results for a specific username                           |
| `NoExport`  | `switch` | (Optional) Skip writing results to file                                     |

---

## 📁 Output

If `-NoExport` is not used, the script writes results to:

```
%USERPROFILE%\Desktop\Veeam_Credentials.txt
```

Each entry includes:

- Username  
- Encrypted password  
- Decrypted password (if successful)  

---

## 🔍 Password Format Detection

The script identifies password format using the first character of the encrypted string:

| Format Prefix | Description                        |
|---------------|------------------------------------|
| `A...`        | Veeam v12 and lower                |
| `V...`        | Veeam v12.1 and up (salted)        |
| Other         | Unknown format                     |

---

## 🔓 Decryption Logic

- **v12 and lower**: Uses `ProtectedData.Unprotect` without salt  
- **v12.1 and up**: Uses `ProtectedData.Unprotect` with registry-based salt  

---

## 🛠 Requirements

- PowerShell 5.1+  
- Access to registry paths:  
  - `HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication\DatabaseConfigurations`  
  - `HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication\Data`  
- For PostgreSQL:  
  - `Npgsql` .NET assembly (optional, falls back to ODBC if unavailable)  

---

## ⚠️ Notes

- PostgreSQL password must be entered manually when prompted  
- If `Username` is passed but empty/whitespace, all credentials are skipped  
- If no credentials match the filter, a warning is displayed  

---

## 📌 Example

```powershell
.\Export-VeeamCredentials.ps1 -Username "admin"
```

Exports credentials for user `admin` and saves them to file.

```powershell
.\Export-VeeamCredentials.ps1 -NoExport
```

Displays all credentials in console without saving to file.

---

## 📄 License

This script is provided "as-is" without warranty. Use at your own risk.
It was based on information in the Veeam KB article https://www.veeam.com/kb4349 

---

## ✨ Author

Created by Didier Van Hoye  
Feel free to contribute or suggest improvements!

