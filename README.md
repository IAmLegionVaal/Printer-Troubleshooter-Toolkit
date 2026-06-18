# Printer Troubleshooter Toolkit

A menu-driven PowerShell toolkit for L1/L2 IT support printer troubleshooting.

This project helps collect printer support evidence for common helpdesk scenarios, including printer status, default printer, print queue state, printer ports, drivers, network printer reachability, and print-related event logs.

## Features

- Quick printer summary
- Full printer troubleshooting report
- Print Spooler service check
- Installed printer inventory
- Default printer detection
- Print queue checks
- Printer port inventory
- Network printer IP reachability checks
- Common printer TCP port tests
- Printer driver inventory
- PrintService event log summary
- Evidence exports for ticket escalation
- Confirmation prompts before service or queue maintenance actions
- HTML, CSV, JSON, and log output

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or later
- Administrator rights recommended
- PrintManagement PowerShell cmdlets

## How to run

Open PowerShell as Administrator and run:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Printer_Troubleshooter_Toolkit.ps1
```

Run a full report directly:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Printer_Troubleshooter_Toolkit.ps1 -RunAll
```

## Menu options

| Option | Description |
|---|---|
| 1 | Quick printer summary |
| 2 | Full printer troubleshooting report |
| 3 | Spooler service and spool folder check |
| 4 | Installed printers and default printer check |
| 5 | Print queue check |
| 6 | Printer ports and IP reachability check |
| 7 | Printer driver inventory |
| 8 | Restart Print Spooler service |
| 9 | Queue maintenance action |
| 10 | Test printer IP or hostname |
| 11 | Export printer evidence package |
| 12 | Open Windows printer settings |
| 13 | Open report folder |

## Output

Reports are saved on the desktop in `Printer_Troubleshooter_Reports` by default.

## Suggested repo topics

```text
powershell
windows
printer
print-spooler
it-support
helpdesk
troubleshooting
sysadmin
network-printer
```
