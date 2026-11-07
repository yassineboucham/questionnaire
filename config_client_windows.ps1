# =====================================================================
# config_client_windows.ps1 : configuration du client Windows
# Laboratoire : Administration des services reseaux
#
# Client : CLTW01-Boucham (LAN 1, 10.10.10.0/24, adresse en DHCP)
#
# Usage (PowerShell ouvert en administrateur) :
#   powershell -ExecutionPolicy Bypass -File .\config_client_windows.ps1
# =====================================================================

$NewHost = "CLTW01-Boucham"
$Gateway = "10.10.10.254"

# --- Verification des droits administrateur ---
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Write-Host "Erreur : lancez PowerShell en tant qu'administrateur." -ForegroundColor Red
    exit 1
}

# --- Choix de la carte reseau ---
Write-Host ""
Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Format-Table Name, InterfaceDescription, Status -AutoSize
$defaut = (Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1).Name
$nic = Read-Host "Carte reseau connectee au LAN [$defaut]"
if ([string]::IsNullOrWhiteSpace($nic)) { $nic = $defaut }
if (-not (Get-NetAdapter -Name $nic -ErrorAction SilentlyContinue)) {
    Write-Host "Erreur : la carte $nic est introuvable." -ForegroundColor Red
    exit 1
}

# --- Configuration DHCP ---
Write-Host "Configuration DHCP de la carte $nic..."
Set-NetIPInterface -InterfaceAlias $nic -Dhcp Enabled
Remove-NetRoute -InterfaceAlias $nic -DestinationPrefix "0.0.0.0/0" -Confirm:$false -ErrorAction SilentlyContinue
Set-DnsClientServerAddress -InterfaceAlias $nic -ResetServerAddresses
ipconfig /release | Out-Null
ipconfig /renew   | Out-Null
Start-Sleep -Seconds 5

# --- Nom de l'ordinateur ---
if ($env:COMPUTERNAME -ne $NewHost) {
    Rename-Computer -NewName $NewHost -Force
    $redemarrage = $true
    Write-Host "Nom de l'ordinateur change en $NewHost (redemarrage necessaire)."
} else {
    $redemarrage = $false
    Write-Host "Nom de l'ordinateur deja correct : $NewHost"
}

# --- Verification ---
Write-Host ""
Write-Host "=== Configuration IP ===" -ForegroundColor Cyan
ipconfig /all

Write-Host ""
Write-Host "=== Tests de connectivite ===" -ForegroundColor Cyan
if (Test-Connection -ComputerName $Gateway -Count 2 -Quiet) { Write-Host "Passerelle $Gateway : OK" -ForegroundColor Green } else { Write-Host "Passerelle $Gateway : ECHEC" -ForegroundColor Red }
if (Test-Connection -ComputerName 8.8.8.8 -Count 2 -Quiet)  { Write-Host "Internet (8.8.8.8)  : OK" -ForegroundColor Green } else { Write-Host "Internet (8.8.8.8)  : ECHEC" -ForegroundColor Red }
try { Resolve-DnsName example.com -ErrorAction Stop | Out-Null; Write-Host "DNS (example.com)  : OK" -ForegroundColor Green } catch { Write-Host "DNS (example.com)  : ECHEC" -ForegroundColor Red }

if ($redemarrage) {
    Write-Host ""
    $rep = Read-Host "Redemarrer maintenant pour appliquer le nom ? [o/N]"
    if ($rep -eq "o") { Restart-Computer -Force }
}
