#Requires -Version 5.1
<#
.SYNOPSIS
    Audits one printer queue, optionally applying B&W one-sided defaults.
.NOTES
    Applying defaults is opt-in. Supports -WhatIf and -Confirm.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$PrinterName,
    [switch]$ApplyMonochromeSimplex
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try {
    Import-Module PrintManagement -ErrorAction Stop
    $printer = Get-Printer -Name $PrinterName -ErrorAction Stop
    $config = Get-PrintConfiguration -PrinterName $PrinterName -ErrorAction Stop
    $port = Get-PrinterPort -Name $printer.PortName -ErrorAction Stop
    [pscustomobject]@{
        Printer = $printer.Name
        Driver = $printer.DriverName
        Port = $port.Name
        PortDescription = $port.Description
        Status = $printer.PrinterStatus
        Color = $config.Color
        DuplexingMode = $config.DuplexingMode
    } | Format-List

    if ($ApplyMonochromeSimplex) {
        if ($PSCmdlet.ShouldProcess($PrinterName, 'Set B&W and one-sided printing defaults')) {
            Set-PrintConfiguration -PrinterName $PrinterName -Color $false -DuplexingMode OneSided -ErrorAction Stop
            $result = Get-PrintConfiguration -PrinterName $PrinterName -ErrorAction Stop
            if ($result.Color -ne $false -or $result.DuplexingMode.ToString() -ne 'OneSided') {
                throw 'Printer defaults do not match requested settings.'
            }
            Write-Host 'Verified printer defaults: Color=False, DuplexingMode=OneSided'
        }
    }
} catch {
    Write-Error ('Printer queue audit failed: {0}' -f $_.Exception.Message)
    throw
}
