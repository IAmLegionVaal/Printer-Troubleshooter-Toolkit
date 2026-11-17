# Field case: USB multifunction printer recovered after re-detection and print configuration changes

**Incident month:** November 2026. **Status:** Windows test page printed. Physical end-user acceptance pending at last update.

## Observed
A colour multifunction printer was present on Windows USB002; several printer drivers / queues were installed, including generic PostScript options. Printing was not working as intended.

## Actions that worked
1. Recorded the existing queues, drivers and USB002 port.
2. Removed the device using Device Manager, then restarted the endpoint.
3. Windows automatically re-detected the connected printer using **the same USB002 port**. No new printer port was needed.
4. Corrected the printer queue / print processor configuration.
5. Applied `Color = False` and `DuplexingMode = OneSided` defaults using PowerShell.
6. Confirmed a successful Windows test page. Per-application preference and production workflow still required verification.

## Reusable commands
```powershell
Get-Printer | Format-Table Name,DriverName,PortName,PrinterStatus
Get-PrinterPort -Name USB002
Get-PrintConfiguration -PrinterName 'Example Printer'
# Run only when the required queue is correctly identified:
Set-PrintConfiguration -PrinterName 'Example Printer' -Color $false -DuplexingMode OneSided
Get-PrintConfiguration -PrinterName 'Example Printer'
```

## Caution
Avoid deleting all drivers, resetting the entire Print Spooler queue or creating USB003/USB004 arbitrarily. Correct print processor selection is model/driver-specific. The case does not prove a unique firmware or driver root cause.
