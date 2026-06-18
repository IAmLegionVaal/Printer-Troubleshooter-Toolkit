#requires -Version 5.1
<#
.SYNOPSIS
    Printer Troubleshooter Toolkit.

.DESCRIPTION
    Menu-driven PowerShell toolkit for L1/L2 IT support printer troubleshooting.
    Collects printer, queue, driver, port, spooler, event log, and network printer
    reachability information. Maintenance actions require confirmation.

.NOTES
    Author: Dewald Pretorius / Dtech IT Solutions
    Version: 1.0.1
    PowerShell: Windows PowerShell 5.1+
    Platform: Windows 10 / Windows 11
#>

[CmdletBinding()]
param(
    [switch]$RunAll,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$ScriptVersion = '1.0.1'
$RunStamp = Get-Date -Format 'yyyyMMdd_HHmmss'

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Initialize-ReportFolder {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        $desktop = [Environment]::GetFolderPath('Desktop')
        $Path = Join-Path $desktop 'Printer_Troubleshooter_Reports'
    }
    New-Item -Path $Path -ItemType Directory -Force | Out-Null
    return $Path
}

$ReportRoot = Initialize-ReportFolder -Path $OutputPath
$LogFile = Join-Path $ReportRoot "PrinterTroubleshooter_$RunStamp.log"

function Write-Log {
    param(
        [Parameter(Mandatory)] [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','SUCCESS')] [string]$Level = 'INFO'
    )
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
    switch ($Level) {
        'WARN'    { Write-Host $Message -ForegroundColor Yellow }
        'ERROR'   { Write-Host $Message -ForegroundColor Red }
        'SUCCESS' { Write-Host $Message -ForegroundColor Green }
        default   { Write-Host $Message }
    }
}

function Pause-Menu {
    Write-Host
    [void](Read-Host 'Press Enter to return to the menu')
}

function Confirm-ToolkitAction {
    param([Parameter(Mandatory)] [string]$Message)
    $answer = Read-Host "$Message Type YES to continue"
    return ($answer -eq 'YES')
}

function Show-Header {
    Clear-Host
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '   PRINTER TROUBLESHOOTER TOOLKIT' -ForegroundColor Cyan
    Write-Host "   Version $ScriptVersion" -ForegroundColor DarkCyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ("   Computer : {0}" -f $env:COMPUTERNAME)
    Write-Host ("   User     : {0}\{1}" -f $env:USERDOMAIN, $env:USERNAME)
    Write-Host ("   Admin    : {0}" -f (Test-IsAdministrator))
    Write-Host ("   Reports  : {0}" -f $ReportRoot)
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host
}

function New-Check {
    param(
        [Parameter(Mandatory)] [string]$Category,
        [Parameter(Mandatory)] [string]$Name,
        [ValidateSet('OK','Warning','Critical','Info')] [string]$Status = 'Info',
        [string]$Value = '',
        [string]$Recommendation = ''
    )
    [PSCustomObject]@{
        Category       = $Category
        Name           = $Name
        Status         = $Status
        Value          = $Value
        Recommendation = $Recommendation
    }
}

function Export-ToolkitReport {
    param(
        [Parameter(Mandatory)] [object[]]$Checks,
        [Parameter(Mandatory)] [string]$ReportName,
        [switch]$OpenReport
    )
    $safeName = $ReportName -replace '[^\w\-]', '_'
    $csvPath = Join-Path $ReportRoot "$safeName`_$RunStamp.csv"
    $jsonPath = Join-Path $ReportRoot "$safeName`_$RunStamp.json"
    $htmlPath = Join-Path $ReportRoot "$safeName`_$RunStamp.html"
    $Checks | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    $Checks | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonPath -Encoding UTF8
    $htmlHeader = @"
<h1>$ReportName</h1>
<p><b>Computer:</b> $env:COMPUTERNAME<br><b>User:</b> $env:USERDOMAIN\$env:USERNAME<br><b>Generated:</b> $(Get-Date)<br><b>Administrator:</b> $(Test-IsAdministrator)</p>
<style>body{font-family:Segoe UI,Arial;margin:24px}table{border-collapse:collapse;width:100%}th,td{border:1px solid #ccc;padding:8px;vertical-align:top}th{background:#eee}.OK{color:green;font-weight:bold}.Warning{color:#b8860b;font-weight:bold}.Critical{color:red;font-weight:bold}.Info{color:#555;font-weight:bold}</style>
"@
    $table = $Checks | ConvertTo-Html -Fragment -Property Category,Name,Status,Value,Recommendation
    $table = $table -replace '<td>OK</td>', '<td class="OK">OK</td>'
    $table = $table -replace '<td>Warning</td>', '<td class="Warning">Warning</td>'
    $table = $table -replace '<td>Critical</td>', '<td class="Critical">Critical</td>'
    $table = $table -replace '<td>Info</td>', '<td class="Info">Info</td>'
    ConvertTo-Html -Title $ReportName -Body ($htmlHeader + $table) | Set-Content -Path $htmlPath -Encoding UTF8
    Write-Log "Created HTML report: $htmlPath" 'SUCCESS'
    Write-Log "Created CSV report: $csvPath" 'SUCCESS'
    Write-Log "Created JSON report: $jsonPath" 'SUCCESS'
    if ($OpenReport) {
        try { Start-Process $htmlPath } catch { Write-Log "Could not open report automatically: $($_.Exception.Message)" 'WARN' }
    }
}

function Show-ChecksAndExport {
    param([object[]]$Checks, [string]$ReportName, [switch]$OpenReport)
    $Checks | Sort-Object Category, Status, Name | Format-Table Category, Name, Status, Value, Recommendation -AutoSize -Wrap
    Export-ToolkitReport -Checks $Checks -ReportName $ReportName -OpenReport:$OpenReport
}

function Get-SpoolerChecks {
    $checks = @()
    try {
        $service = Get-Service -Name Spooler -ErrorAction Stop
        $status = if ($service.Status -eq 'Running') { 'OK' } else { 'Critical' }
        $checks += New-Check 'Spooler' 'Print Spooler service' $status "Status: $($service.Status); StartType: $($service.StartType)" 'Print Spooler must be running for normal printing.'
        $spoolerFolder = Join-Path $env:SystemRoot 'System32\spool\PRINTERS'
        if (Test-Path $spoolerFolder) {
            $files = Get-ChildItem -Path $spoolerFolder -Force -ErrorAction SilentlyContinue
            $count = @($files).Count
            $sizeMB = [math]::Round((($files | Measure-Object Length -Sum).Sum / 1MB), 2)
            $fileStatus = if ($count -gt 0) { 'Warning' } else { 'OK' }
            $checks += New-Check 'Spooler' 'Spool folder file count' $fileStatus "$count file(s), $sizeMB MB" 'Files here can indicate print queue activity or stuck jobs.'
        }
        else {
            $checks += New-Check 'Spooler' 'Spool folder' 'Warning' 'Folder not found' 'Check Windows print subsystem.'
        }
    }
    catch { $checks += New-Check 'Spooler' 'Spooler query' 'Critical' $_.Exception.Message 'Run as Administrator and retry.' }
    return $checks
}

function Get-PrinterInventoryChecks {
    $checks = @()
    try {
        $printers = Get-Printer -ErrorAction Stop
        if (-not $printers) { $checks += New-Check 'Printers' 'Installed printers' 'Warning' 'No printers installed' 'Add or reinstall the required printer.'; return $checks }
        $defaultPrinter = $printers | Where-Object { $_.Default -eq $true } | Select-Object -First 1
        if ($defaultPrinter) { $checks += New-Check 'Printers' 'Default printer' 'OK' $defaultPrinter.Name 'Confirm this is the expected default printer.' }
        else { $checks += New-Check 'Printers' 'Default printer' 'Warning' 'No default printer found' 'Set a default printer if needed.' }
        foreach ($printer in $printers) {
            $printerStatus = if ($printer.PrinterStatus -eq 'Normal') { 'OK' } else { 'Warning' }
            $value = "Driver: $($printer.DriverName); Port: $($printer.PortName); Shared: $($printer.Shared); Status: $($printer.PrinterStatus); Type: $($printer.Type)"
            $checks += New-Check 'Printers' $printer.Name $printerStatus $value 'Check status, driver, and port if user cannot print.'
        }
    }
    catch { $checks += New-Check 'Printers' 'Printer inventory query' 'Critical' $_.Exception.Message 'Run PowerShell as Administrator and retry.' }
    return $checks
}

function Get-PrintQueueChecks {
    $checks = @()
    try {
        $printers = Get-Printer -ErrorAction Stop
        foreach ($printer in $printers) {
            try {
                $jobs = Get-PrintJob -PrinterName $printer.Name -ErrorAction Stop
                $jobCount = @($jobs).Count
                $status = if ($jobCount -gt 0) { 'Warning' } else { 'OK' }
                $checks += New-Check 'Print Queue' $printer.Name $status "$jobCount print job(s)" 'Stuck jobs can block printing for this printer.'
                foreach ($job in $jobs) {
                    $value = "JobId: $($job.ID); Document: $($job.DocumentName); User: $($job.UserName); Size: $($job.Size); Submitted: $($job.SubmittedTime)"
                    $checks += New-Check 'Print Queue' "Job on $($printer.Name)" 'Info' $value 'Review whether this job is expected or stuck.'
                }
            }
            catch { $checks += New-Check 'Print Queue' $printer.Name 'Warning' $_.Exception.Message 'Could not query print jobs for this printer.' }
        }
    }
    catch { $checks += New-Check 'Print Queue' 'Queue query' 'Critical' $_.Exception.Message 'Could not query printers.' }
    return $checks
}

function Get-PrinterPortChecks {
    $checks = @()
    try {
        $ports = Get-PrinterPort -ErrorAction Stop
        if (-not $ports) { $checks += New-Check 'Ports' 'Printer ports' 'Warning' 'No printer ports found' 'Printer installation may be incomplete.'; return $checks }
        foreach ($port in $ports) {
            $hostAddress = $port.PrinterHostAddress
            if ([string]::IsNullOrWhiteSpace($hostAddress)) {
                $checks += New-Check 'Ports' $port.Name 'Info' "Type: $($port.Description); No IP host address" 'Local, USB, WSD, or redirected ports may not have a direct IP.'
                continue
            }
            $ping = Test-Connection -ComputerName $hostAddress -Count 2 -Quiet -ErrorAction SilentlyContinue
            try { $tcp9100 = Test-NetConnection -ComputerName $hostAddress -Port 9100 -InformationLevel Quiet -WarningAction SilentlyContinue } catch { $tcp9100 = $false }
            $status = if ($ping -or $tcp9100) { 'OK' } else { 'Warning' }
            $value = "Host: $hostAddress; Ping: $ping; TCP/9100: $tcp9100; SNMP: $($port.SNMPEnabled)"
            $checks += New-Check 'Ports' $port.Name $status $value 'If reachability fails, check printer power, IP, VLAN, firewall, or port configuration.'
        }
    }
    catch { $checks += New-Check 'Ports' 'Printer port query' 'Critical' $_.Exception.Message 'Run PowerShell as Administrator and retry.' }
    return $checks
}

function Get-PrinterDriverChecks {
    $checks = @()
    try {
        $drivers = Get-PrinterDriver -ErrorAction Stop
        if (-not $drivers) { $checks += New-Check 'Drivers' 'Printer drivers' 'Warning' 'No printer drivers found' 'Install vendor or universal print drivers as required.'; return $checks }
        foreach ($driver in $drivers) {
            $value = "Version: $($driver.MajorVersion); Manufacturer: $($driver.Manufacturer); Environment: $($driver.PrinterEnvironment); Path: $($driver.DriverPath)"
            $checks += New-Check 'Drivers' $driver.Name 'Info' $value 'Confirm the driver is expected and not a legacy/problem driver.'
        }
    }
    catch { $checks += New-Check 'Drivers' 'Printer driver query' 'Warning' $_.Exception.Message 'Could not query printer drivers.' }
    return $checks
}

function Get-PrinterEventChecks {
    param([int]$Hours = 24)
    $checks = @()
    $start = (Get-Date).AddHours(-1 * $Hours)
    foreach ($logName in @('Microsoft-Windows-PrintService/Admin','Microsoft-Windows-PrintService/Operational')) {
        try {
            $events = Get-WinEvent -FilterHashtable @{ LogName = $logName; Level = 1,2,3; StartTime = $start } -ErrorAction Stop
            $count = @($events).Count
            $status = if ($count -gt 20) { 'Warning' } elseif ($count -gt 0) { 'Info' } else { 'OK' }
            $checks += New-Check 'Events' "$logName last $Hours hours" $status "$count warning/error event(s)" 'Review print service events if symptoms match.'
            $events | Group-Object Id | Sort-Object Count -Descending | Select-Object -First 5 | ForEach-Object { $checks += New-Check 'Events' "Event ID $($_.Name) in $logName" 'Info' "$($_.Count) event(s)" 'Use Event Viewer for event details.' }
        }
        catch { $checks += New-Check 'Events' $logName 'Info' $_.Exception.Message 'Log may be disabled or unavailable.' }
    }
    return $checks
}

function Export-PrinterEvidence {
    $checks = @()
    try {
        $path = Join-Path $ReportRoot "printers_$RunStamp.csv"
        Get-Printer | Select-Object Name,DriverName,PortName,PrinterStatus,Default,Shared,Type | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
        $checks += New-Check 'Exports' 'Printer inventory' 'OK' $path 'Attach this file to tickets when useful.'
    } catch { $checks += New-Check 'Exports' 'Printer inventory' 'Warning' $_.Exception.Message 'Export failed.' }
    try {
        $path = Join-Path $ReportRoot "printer_ports_$RunStamp.csv"
        Get-PrinterPort | Select-Object Name,PrinterHostAddress,PortNumber,Description,SNMPEnabled | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
        $checks += New-Check 'Exports' 'Printer ports' 'OK' $path 'Attach this file to tickets when useful.'
    } catch { $checks += New-Check 'Exports' 'Printer ports' 'Warning' $_.Exception.Message 'Export failed.' }
    try {
        $path = Join-Path $ReportRoot "printer_drivers_$RunStamp.csv"
        Get-PrinterDriver | Select-Object Name,Manufacturer,PrinterEnvironment,MajorVersion,DriverPath | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
        $checks += New-Check 'Exports' 'Printer drivers' 'OK' $path 'Attach this file to tickets when useful.'
    } catch { $checks += New-Check 'Exports' 'Printer drivers' 'Warning' $_.Exception.Message 'Export failed.' }
    try {
        $path = Join-Path $ReportRoot "print_jobs_$RunStamp.csv"
        Get-Printer | ForEach-Object { Get-PrintJob -PrinterName $_.Name -ErrorAction SilentlyContinue } | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
        $checks += New-Check 'Exports' 'Print jobs' 'OK' $path 'Attach this file to tickets when useful.'
    } catch { $checks += New-Check 'Exports' 'Print jobs' 'Warning' $_.Exception.Message 'Export failed.' }
    try {
        $spoolFolder = Join-Path $env:SystemRoot 'System32\spool\PRINTERS'
        $path = Join-Path $ReportRoot "spool_folder_listing_$RunStamp.txt"
        if (Test-Path $spoolFolder) {
            Get-ChildItem -Path $spoolFolder -Force -ErrorAction SilentlyContinue | Select-Object Name,Length,CreationTime,LastWriteTime | Format-Table -AutoSize | Out-File -FilePath $path -Encoding UTF8
            $checks += New-Check 'Exports' 'Spool folder listing' 'OK' $path 'Listing only; spool files are not copied.'
        }
    } catch { $checks += New-Check 'Exports' 'Spool folder listing' 'Warning' $_.Exception.Message 'Export failed.' }
    return $checks
}

function Invoke-QuickPrinterSummary {
    Show-Header
    Write-Host '[1] Quick printer summary' -ForegroundColor Cyan
    $checks = @()
    $checks += Get-SpoolerChecks
    $checks += Get-PrinterInventoryChecks
    $checks += Get-PrintQueueChecks
    Show-ChecksAndExport -Checks $checks -ReportName 'Quick_Printer_Summary'
    Pause-Menu
}

function Invoke-FullPrinterReport {
    Show-Header
    Write-Host '[2] Full printer troubleshooting report' -ForegroundColor Cyan
    $checks = @()
    $checks += Get-SpoolerChecks
    $checks += Get-PrinterInventoryChecks
    $checks += Get-PrintQueueChecks
    $checks += Get-PrinterPortChecks
    $checks += Get-PrinterDriverChecks
    $checks += Get-PrinterEventChecks -Hours 24
    $checks += Export-PrinterEvidence
    Show-ChecksAndExport -Checks $checks -ReportName 'Full_Printer_Troubleshooting_Report' -OpenReport
    Pause-Menu
}

function Invoke-SingleCheck {
    param([Parameter(Mandatory)] [string]$Name)
    Show-Header
    $checks = switch ($Name) {
        'Spooler'  { Get-SpoolerChecks }
        'Printers' { Get-PrinterInventoryChecks }
        'Queues'   { Get-PrintQueueChecks }
        'Ports'    { Get-PrinterPortChecks }
        'Drivers'  { Get-PrinterDriverChecks }
        'Events'   { Get-PrinterEventChecks -Hours 24 }
        'Exports'  { Export-PrinterEvidence }
    }
    Show-ChecksAndExport -Checks $checks -ReportName "$Name`_Check"
    Pause-Menu
}

function Invoke-RestartSpooler {
    Show-Header
    Write-Host '[8] Restart Print Spooler service' -ForegroundColor Cyan
    Write-Host 'WARNING: This interrupts printing and can affect all installed printers.' -ForegroundColor Yellow
    if (-not (Test-IsAdministrator)) { Write-Log 'Administrator rights are required.' 'ERROR'; Pause-Menu; return }
    if (-not (Confirm-ToolkitAction 'Restart the Print Spooler now?')) { Write-Log 'Operation cancelled.'; Pause-Menu; return }
    try {
        Restart-Service -Name Spooler -Force -ErrorAction Stop
        Start-Sleep -Seconds 2
        $service = Get-Service -Name Spooler
        Write-Log "Print Spooler restarted. Current status: $($service.Status)" 'SUCCESS'
    }
    catch { Write-Log "Could not restart Print Spooler: $($_.Exception.Message)" 'ERROR' }
    Pause-Menu
}

function Invoke-QueueMaintenanceGuidance {
    Show-Header
    Write-Host '[9] Queue maintenance guidance' -ForegroundColor Cyan
    Write-Host 'This option shows queue state and opens printer settings for manual review.' -ForegroundColor Yellow
    $checks = Get-PrintQueueChecks
    Show-ChecksAndExport -Checks $checks -ReportName 'Queue_Maintenance_Guidance'
    try { Start-Process 'ms-settings:printers'; Write-Log 'Opened Windows printer settings.' 'SUCCESS' } catch { Write-Log "Could not open printer settings: $($_.Exception.Message)" 'WARN' }
    Pause-Menu
}

function Invoke-TestPrinterIp {
    Show-Header
    Write-Host '[10] Test printer IP or hostname' -ForegroundColor Cyan
    $target = Read-Host 'Enter printer IP address or hostname'
    if ([string]::IsNullOrWhiteSpace($target)) { Write-Log 'No target entered.' 'WARN'; Pause-Menu; return }
    $checks = @()
    try { $ping = Test-Connection -ComputerName $target -Count 3 -Quiet -ErrorAction SilentlyContinue; $checks += New-Check 'Printer Reachability' "Ping $target" ($(if ($ping) { 'OK' } else { 'Warning' })) "$ping" 'Ping may be blocked even when printing works.' } catch { $checks += New-Check 'Printer Reachability' "Ping $target" 'Warning' $_.Exception.Message 'Ping test failed.' }
    foreach ($port in @(9100,515,631,80,443)) {
        try { $tcp = Test-NetConnection -ComputerName $target -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue; $checks += New-Check 'Printer Reachability' "TCP $target`:$port" ($(if ($tcp) { 'OK' } else { 'Info' })) "$tcp" 'Common printer ports: 9100 RAW, 515 LPR, 631 IPP, 80/443 web admin.' } catch { $checks += New-Check 'Printer Reachability' "TCP $target`:$port" 'Info' $_.Exception.Message 'TCP test failed.' }
    }
    Show-ChecksAndExport -Checks $checks -ReportName "Printer_Reachability_$($target -replace '[^\w\-\.]', '_')"
    Pause-Menu
}

function Invoke-OpenPrinterSettings {
    Show-Header
    Write-Host '[12] Open Windows printer settings' -ForegroundColor Cyan
    try { Start-Process 'ms-settings:printers'; Write-Log 'Opened Windows Printers and scanners settings.' 'SUCCESS' } catch { Write-Log "Could not open printer settings: $($_.Exception.Message)" 'ERROR' }
    Pause-Menu
}

function Open-ReportFolder {
    Show-Header
    Write-Host '[13] Open report folder' -ForegroundColor Cyan
    try { Start-Process explorer.exe -ArgumentList "`"$ReportRoot`""; Write-Log "Opened report folder: $ReportRoot" 'SUCCESS' } catch { Write-Log "Could not open report folder: $($_.Exception.Message)" 'ERROR' }
    Pause-Menu
}

Write-Log "Printer Troubleshooter Toolkit v$ScriptVersion started."
Write-Log "Administrator: $(Test-IsAdministrator)"
Write-Log "Report folder: $ReportRoot"

if ($RunAll) {
    Invoke-FullPrinterReport
    return
}

do {
    Show-Header
    Write-Host '  1. Quick printer summary'
    Write-Host '  2. Full printer troubleshooting report'
    Write-Host '  3. Spooler service and spool folder check'
    Write-Host '  4. Installed printers and default printer check'
    Write-Host '  5. Print queue and stuck jobs check'
    Write-Host '  6. Printer ports and IP reachability check'
    Write-Host '  7. Printer driver inventory'
    Write-Host '  8. Restart Print Spooler service'
    Write-Host '  9. Queue maintenance guidance'
    Write-Host ' 10. Test printer IP or hostname'
    Write-Host ' 11. Export printer evidence package'
    Write-Host ' 12. Open Windows printer settings'
    Write-Host ' 13. Open report folder'
    Write-Host
    Write-Host '  0. Exit'
    Write-Host
    $choice = Read-Host 'Select an option'
    switch ($choice) {
        '1'  { Invoke-QuickPrinterSummary }
        '2'  { Invoke-FullPrinterReport }
        '3'  { Invoke-SingleCheck -Name 'Spooler' }
        '4'  { Invoke-SingleCheck -Name 'Printers' }
        '5'  { Invoke-SingleCheck -Name 'Queues' }
        '6'  { Invoke-SingleCheck -Name 'Ports' }
        '7'  { Invoke-SingleCheck -Name 'Drivers' }
        '8'  { Invoke-RestartSpooler }
        '9'  { Invoke-QueueMaintenanceGuidance }
        '10' { Invoke-TestPrinterIp }
        '11' { Invoke-SingleCheck -Name 'Exports' }
        '12' { Invoke-OpenPrinterSettings }
        '13' { Open-ReportFolder }
        '0'  { Write-Log 'Toolkit closed by the user.'; Write-Host 'Goodbye.' -ForegroundColor Green }
        default { Write-Host 'Invalid selection.' -ForegroundColor Yellow; Start-Sleep -Seconds 1 }
    }
}
while ($choice -ne '0')
