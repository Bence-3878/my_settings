#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Distro,
    [string]$Username,
    [SecureString]$Password,
    [switch]$SkipSetup,
    [switch]$WebDownload
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$env:WSL_UTF8 = '1'

function Write-Step([string]$Msg) { Write-Host "==> $Msg" -ForegroundColor Cyan }
function Write-Warn([string]$Msg) { Write-Host "Figyelmeztetés: $Msg" -ForegroundColor Yellow }
function Fail([string]$Msg) { Write-Host "Hiba: $Msg" -ForegroundColor Red; exit 1 }

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function ConvertFrom-SecureToPlain([SecureString]$Sec) {
    [System.Net.NetworkCredential]::new('', $Sec).Password
}

function Ensure-WslPrerequisites {
    if ([Environment]::OSVersion.Version.Build -lt 19041) {
        Fail "A WSL 2-höz legalább Windows 10 (build 19041) vagy Windows 11 szükséges."
    }

    $sysDrive = $env:SystemDrive.TrimEnd(':')
    $freeGB = [math]::Round((Get-PSDrive $sysDrive).Free / 1GB, 1)
    if ($freeGB -lt 3) { Fail "Kevés a szabad hely a $env:SystemDrive meghajtón (${freeGB} GB). Legalább 3 GB szükséges." }
    if ($freeGB -lt 6) { Write-Warn "Kevés a szabad hely a $env:SystemDrive meghajtón (${freeGB} GB)." }

    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $cs  = Get-CimInstance Win32_ComputerSystem
    if (-not $cs.HypervisorPresent -and -not $cpu.VirtualizationFirmwareEnabled) {
        Fail "A hardveres virtualizáció (Intel VT-x / AMD SVM) ki van kapcsolva a BIOS/UEFI-ben. Kapcsold be, majd indítsd újra a gépet."
    }

    $features = Get-CimInstance Win32_OptionalFeature -Filter "Name='Microsoft-Windows-Subsystem-Linux' OR Name='VirtualMachinePlatform'" -ErrorAction SilentlyContinue
    $missing = @('Microsoft-Windows-Subsystem-Linux', 'VirtualMachinePlatform') | Where-Object {
        $name = $_
        -not ($features | Where-Object { $_.Name -eq $name -and $_.InstallState -eq 1 })
    }

    $hasWsl = [bool](Get-Command wsl.exe -ErrorAction SilentlyContinue)
    if ($missing.Count -gt 0 -or -not $hasWsl) {
        if (-not (Test-IsAdmin)) {
            Fail "A WSL Windows-komponensek engedélyezéséshez futtasd a scriptet rendszergazdaként (Admin PowerShell)!"
        }
        Write-Step "WSL Windows-funkciók engedélyezése ($($missing -join ', '))..."
        $rebootNeeded = $false
        foreach ($feat in $missing) {
            & dism.exe /online /enable-feature /featurename:$feat /all /norestart | Out-Null
            if ($LASTEXITCODE -eq 3010) { $rebootNeeded = $true }
            elseif ($LASTEXITCODE -ne 0) { Fail "Nem sikerült engedélyezni a(z) $feat funkciót (kód: $LASTEXITCODE)." }
        }
        if (-not $hasWsl) {
            & wsl.exe --install --no-distribution
            if ($LASTEXITCODE -eq 3010) { $rebootNeeded = $true }
        }
        if ($rebootNeeded) {
            Write-Warn "A Windows-funkciók engedélyezése megtörtént, de ÚJRAINDÍTÁS szükséges! Indítsd újra a gépet, majd futtasd újra ezt a scriptet."
            exit 0
        }
    }
}

function Ensure-WslConfig {
    $cfgPath = Join-Path $env:USERPROFILE '.wslconfig'
    if (Test-Path $cfgPath) {
        Write-Step ".wslconfig már létezik: $cfgPath"
        return
    }
    $os = Get-CimInstance Win32_OperatingSystem
    $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    $freeGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
    $memGB   = if ($totalGB -le 16 -or $freeGB -lt 3.5) { 2 } else { 4 }
    $procs   = [Math]::Min(4, [Environment]::ProcessorCount)

    $content = "[wsl2]`nmemory=${memGB}GB`nprocessors=$procs`nswap=2GB`n"
    [System.IO.File]::WriteAllText($cfgPath, $content, [System.Text.UTF8Encoding]::new($false))
    Write-Step "Létrehozva: $cfgPath (memory=${memGB}GB, processors=$procs, swap=2GB)"
}

function Get-OnlineDistros {
    $list = @()
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & wsl.exe --list --online 2>&1
    $rc = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    if ($rc -eq 0) {
        foreach ($line in $out) {
            if ($line -match '^\s*([A-Za-z0-9._-]+)\s{2,}(.+?)\s*$' -and $matches[1] -ne 'NAME') {
                $list += [pscustomobject]@{ Name = $matches[1]; Friendly = $matches[2] }
            }
        }
    }
    if ($list.Count -eq 0) {
        $list = @(
            [pscustomobject]@{ Name = 'Ubuntu'; Friendly = 'Ubuntu' },
            [pscustomobject]@{ Name = 'Debian'; Friendly = 'Debian GNU/Linux' },
            [pscustomobject]@{ Name = 'FedoraLinux-45'; Friendly = 'Fedora Linux 45' },
            [pscustomobject]@{ Name = 'archlinux'; Friendly = 'Arch Linux' },
            [pscustomobject]@{ Name = 'openSUSE-Tumbleweed'; Friendly = 'openSUSE Tumbleweed' }
        )
    }
    return $list
}

function Get-InstalledDistros {
    $raw = & wsl.exe -l -q 2>$null
    if ($LASTEXITCODE -ne 0) { return @() }
    return @($raw | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
}

function Select-Distro([string]$Requested) {
    $online = Get-OnlineDistros
    $installed = Get-InstalledDistros

    if (-not [string]::IsNullOrWhiteSpace($Requested)) {
        $match = $online | Where-Object { $_.Name -ieq $Requested } | Select-Object -First 1
        if ($match) { return $match.Name }
        $instMatch = $installed | Where-Object { $_ -ieq $Requested } | Select-Object -First 1
        if ($instMatch) { return $instMatch }
        Fail "Ismeretlen disztribúció: '$Requested'. Elérhető nevek: $($online.Name -join ', ')"
    }

    Write-Host "`nMit szeretnél telepíteni? Elérhető Linux disztribúciók:" -ForegroundColor Green
    for ($i = 0; $i -lt $online.Count; $i++) {
        $tag = if ($installed -contains $online[$i].Name) { ' [telepítve]' } else { '' }
        Write-Host ("  [{0,2}] {1,-28} ({2}){3}" -f ($i + 1), $online[$i].Name, $online[$i].Friendly, $tag)
    }
    $choice = Read-Host "`nVálassz sorszámot vagy nevet (alap: Debian)"
    if ([string]::IsNullOrWhiteSpace($choice)) { return 'Debian' }
    if ($choice -match '^\d+$') {
        $idx = [int]$choice - 1
        if ($idx -ge 0 -and $idx -lt $online.Count) { return $online[$idx].Name }
        Fail "Érvénytelen sorszám: $choice"
    }
    $byName = $online | Where-Object { $_.Name -ieq $choice.Trim() } | Select-Object -First 1
    if (-not $byName) { Fail "Ismeretlen disztribúció: '$choice'" }
    return $byName.Name
}

function Get-DefaultLinuxUsername {
    $norm = $env:USERNAME.Normalize([System.Text.NormalizationForm]::FormD)
    $ascii = -join ($norm.ToCharArray() | Where-Object {
        [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne [System.Globalization.UnicodeCategory]::NonSpacingMark
    })
    $clean = ($ascii.ToLowerInvariant() -replace '[^a-z0-9_-]', '')
    if ($clean -notmatch '^[a-z_]') { $clean = 'user' }
    return $clean
}

function Prompt-LinuxCredentials([string]$DistroName, [string]$ReqUser, [SecureString]$ReqPass) {
    $defUser = Get-DefaultLinuxUsername
    if ([string]::IsNullOrWhiteSpace($ReqUser)) {
        $inUser = Read-Host "Linux felhasználónév a(z) '$DistroName' rendszerhez (alap: $defUser)"
        $ReqUser = if ([string]::IsNullOrWhiteSpace($inUser)) { $defUser } else { $inUser.Trim() }
    }
    if ($ReqUser -notmatch '^[a-z_][a-z0-9_-]{0,31}$') {
        Fail "Érvénytelen Linux felhasználónév: '$ReqUser' (csak kisbetű, szám, _ és - engedélyezett)."
    }

    if (-not $ReqPass) {
        $ReqPass = Read-Host "Linux/sudo jelszó '$ReqUser' számára (csak a memóriában marad)" -AsSecureString
    }
    if ($ReqPass.Length -eq 0) {
        Fail "A jelszó nem lehet üres."
    }
    return [pscustomobject]@{ Username = $ReqUser; Password = $ReqPass }
}

function Invoke-WslWithTimeout([string[]]$WslArgs, [int]$TimeoutMs = 30000) {
    $outFile = [System.IO.Path]::GetTempFileName()
    $errFile = [System.IO.Path]::GetTempFileName()
    try {
        $p = Start-Process wsl.exe -ArgumentList $WslArgs -NoNewWindow -PassThru `
            -RedirectStandardOutput $outFile -RedirectStandardError $errFile
        if (-not $p.WaitForExit($TimeoutMs)) {
            try { $p.Kill() } catch {}
            return [pscustomobject]@{ TimedOut = $true; ExitCode = -1; Output = 'TIMEOUT' }
        }
        $p.WaitForExit()
        $txt = ((Get-Content $outFile -Raw -ErrorAction SilentlyContinue) + "`n" +
                (Get-Content $errFile -Raw -ErrorAction SilentlyContinue)).Trim()
        return [pscustomobject]@{ TimedOut = $false; ExitCode = [int]$p.ExitCode; Output = $txt }
    } finally {
        Remove-Item $outFile, $errFile -Force -ErrorAction SilentlyContinue
    }
}

function Reset-WslService {
    Write-Warn "A WSL VM/szolgáltatás válasza elakadt, újraindítás (wsl --shutdown)..."
    $res = Invoke-WslWithTimeout -WslArgs @('--shutdown') -TimeoutMs 15000
    if ($res.TimedOut) {
        if (Test-IsAdmin) {
            Write-Warn "A 'wsl --shutdown' túllépte az időkeretet; WslService és vmcompute újraindítása..."
            Stop-Process -Name vmmem, vmwp -Force -ErrorAction SilentlyContinue
            Restart-Service vmcompute, WslService -Force -ErrorAction Stop
        } else {
            Fail "A 'wsl --shutdown' elakadt (beragadt WslService/vmmem). Nyiss Rendszergazda PowerShellt és futtasd: Restart-Service vmcompute, WslService -Force (vagy indítsd újra a gépet)."
        }
    }
    Start-Sleep -Seconds 2
}

function Install-OrUpdate-Distro([string]$Name) {
    $installed = Get-InstalledDistros
    if ($installed -contains $Name) {
        Write-Step "A(z) '$Name' disztribúció már telepítve van."
    } else {
        Write-Step "Telepítés indítása: $Name ..."
        $installArgs = @('--install', '-d', $Name, '--no-launch')
        if ($WebDownload) { $installArgs += '--web-download' }

        & wsl.exe @installArgs
        if ($LASTEXITCODE -ne 0 -and -not $WebDownload) {
            Write-Warn "Az alapértelmezett telepítés sikertelen (kód: $LASTEXITCODE), újrapróbálás --web-download módban..."
            & wsl.exe --install -d $Name --no-launch --web-download
        }
        if ($LASTEXITCODE -eq 3010) {
            Write-Warn "Újraindítás szükséges a telepítés befejezéséhez."
            exit 0
        }
        if ($LASTEXITCODE -ne 0) {
            Fail "A(z) '$Name' telepítése sikertelen (kilépési kód: $LASTEXITCODE). Ellenőrizd az internetkapcsolatot vagy futtasd Rendszergazdaként."
        }
    }

    $verLine = (& wsl.exe -l -v 2>$null) | Where-Object { $_ -match "^\s*\*?\s*$([regex]::Escape($Name))\s+" } | Select-Object -First 1
    if ($verLine -match '\s1\s*$') {
        Write-Step "'$Name' átállítása WSL 2 verzióra..."
        & wsl.exe --set-version $Name 2
        if ($LASTEXITCODE -ne 0) { Fail "Nem sikerült WSL 2-re állítani a(z) '$Name' disztribúciót." }
    }
}

function Ensure-DistroUser([string]$Name, [string]$User, [SecureString]$Pass) {
    Write-Step "Felhasználó ellenőrzése / beállítása ($Name -> $User)..."
    $plain = ConvertFrom-SecureToPlain $Pass
    $linuxScript = @'
set -e
TARGET_USER="$1"
IFS= read -r TARGET_PASS <&3
exec 3<&-
TARGET_PASS="${TARGET_PASS%$'\r'}"

# Alap csomagok biztosítása (sudo + useradd/chpasswd) új Arch/Fedora/Debian image-eken
if ! command -v sudo >/dev/null 2>&1 || ! command -v useradd >/dev/null 2>&1 || ! command -v chpasswd >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq sudo passwd
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y -q sudo shadow-utils
  elif command -v pacman >/dev/null 2>&1; then
    if [ ! -s /etc/pacman.d/gnupg/pubring.gpg ]; then
      pacman-key --init
      pacman-key --populate archlinux
    fi
    pacman -Syu --noconfirm --needed sudo shadow
  elif command -v zypper >/dev/null 2>&1; then
    zypper --non-interactive install -y sudo shadow
  fi
fi

# Sudoers wheel csoport engedélyezése (Arch / Fedora / openSUSE)
if [ -d /etc/sudoers.d ]; then
  if getent group wheel >/dev/null 2>&1 && [ ! -f /etc/sudoers.d/10-wheel ]; then
    echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
    chmod 440 /etc/sudoers.d/10-wheel
  fi
fi

CREATED=0
if ! id "$TARGET_USER" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$TARGET_USER"
  printf '%s:%s\n' "$TARGET_USER" "$TARGET_PASS" | chpasswd
  CREATED=1
fi

if getent group sudo >/dev/null 2>&1; then
  usermod -aG sudo "$TARGET_USER"
elif getent group wheel >/dev/null 2>&1; then
  usermod -aG wheel "$TARGET_USER"
fi

# Alapértelmezett WSL user beállítása az /etc/wsl.conf-ban
touch /etc/wsl.conf
if ! grep -q '^\[user\]' /etc/wsl.conf 2>/dev/null; then
  printf '\n[user]\ndefault=%s\n' "$TARGET_USER" >> /etc/wsl.conf
fi
echo "USER_READY=$TARGET_USER CREATED=$CREATED"
'@ -replace "`r`n", "`n"

    $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($linuxScript))
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $res = ($plain + "`n") | & wsl.exe -d $Name -u root -- bash -c "exec 3<&0; echo $b64 | base64 -d | bash -s -- '$User'" 2>&1
        $rc = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevEap
        $plain = $null
    }
    $outText = (($res | ForEach-Object { "$_" }) -join "`n").Trim()
    if ($rc -ne 0) {
        Fail "Nem sikerült beállítani a(z) '$User' felhasználót a '$Name' disztribúcióban: $outText"
    }
    Write-Host "    $outText"
    if ($outText -match 'CREATED=1') {
        & wsl.exe --terminate $Name | Out-Null
    }
}

function Test-DistroHealth([string]$Name) {
    Write-Step "WSL működés ellenőrzése ($Name)..."
    $res = Invoke-WslWithTimeout -WslArgs @('-d', $Name, '--', 'uname', '-sr') -TimeoutMs 35000
    if ($res.TimedOut -or ($res.ExitCode -ne 0 -and $res.Output -match 'ERROR_TIMEOUT|CreateInstance|CreateVm')) {
        if ($res.Output -match 'ERROR_NO_SYSTEM_RESOURCES') {
            Fail "Kevés a szabad memória a WSL 2 VM indításához ($($res.Output)). Zárj be appokat vagy csökkentsd a memory= értéket itt: $env:USERPROFILE\.wslconfig"
        }
        Reset-WslService
        $res = Invoke-WslWithTimeout -WslArgs @('-d', $Name, '--', 'uname', '-sr') -TimeoutMs 35000
    }
    if ($res.TimedOut -or $res.ExitCode -ne 0) {
        Fail "Nem indítható a(z) '$Name' disztribúció: $($res.Output)"
    }
    Write-Host "    Kernel: $($res.Output)"

    $net = Invoke-WslWithTimeout -WslArgs @('-d', $Name, '--', 'bash', '-c', 'getent hosts github.com >/dev/null 2>&1 || ping -c1 -W2 1.1.1.1 >/dev/null 2>&1') -TimeoutMs 15000
    if ($net.TimedOut -or $net.ExitCode -ne 0) {
        Write-Warn "A DNS/hálózat ellenőrzés hibát jelzett a WSL-ben; a csomagtelepítés internetkapcsolatot igényel."
    } else {
        Write-Host "    Hálózat/DNS: OK"
    }
}

function Invoke-RepoSetup([string]$Name, [string]$User, [SecureString]$Pass) {
    $winRepo = $PSScriptRoot
    if ($winRepo -match '^([A-Za-z]):\\(.*)$') {
        $wslRepo = "/mnt/$($matches[1].ToLower())/" + ($matches[2] -replace '\\', '/')
    } else {
        $fwd = $winRepo -replace '\\', '/'
        $wslRepo = (& wsl.exe -d $Name -- wslpath -a $fwd 2>$null | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($wslRepo)) {
            Fail "Nem sikerült WSL útvonallá alakítani: $winRepo"
        }
    }

    Write-Step "Linux/WSL beállító script automatikus indítása ($User @ $Name): $wslRepo/install.sh"
    $plain = ConvertFrom-SecureToPlain $Pass
    $runner = @'
set -e
REPO_INSTALL="$1"
IFS= read -r PW <&3
exec 3<&-
PW="${PW%$'\r'}"
PW_B64=$(printf '%s' "$PW" | base64 | tr -d '\r\n')
unset PW
ASKPASS="$(mktemp)"
chmod 700 "$ASKPASS"
trap 'rm -f "$ASKPASS"' EXIT
cat << EOF > "$ASKPASS"
#!/bin/sh
printf '%s\n' "\$(printf '%s' '$PW_B64' | base64 -d)"
EOF
export SUDO_ASKPASS="$ASKPASS"
sudo -A -v
sh "$REPO_INSTALL" </dev/null
'@ -replace "`r`n", "`n"

    $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($runner))
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        ($plain + "`n") | & wsl.exe -d $Name -u $User -- bash -c "exec 3<&0; echo $b64 | base64 -d | bash -s -- '$wslRepo/install.sh'"
        $rc = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevEap
        $plain = $null
    }
    if ($rc -ne 0) {
        Fail "Az install.sh futtatása hibával tért vissza (kód: $rc)."
    }
}

# --- Fő futás ---
Ensure-WslPrerequisites
Ensure-WslConfig

Write-Step "Alapértelmezett WSL verzió beállítása: 2"
& wsl.exe --set-default-version 2 | Out-Null

$selected = Select-Distro -Requested $Distro
$creds = $null
if (-not $SkipSetup) {
    $creds = Prompt-LinuxCredentials -DistroName $selected -ReqUser $Username -ReqPass $Password
}

Install-OrUpdate-Distro -Name $selected
Test-DistroHealth -Name $selected

if (-not $SkipSetup) {
    Ensure-DistroUser -Name $selected -User $creds.Username -Pass $creds.Password
    Invoke-RepoSetup -Name $selected -User $creds.Username -Pass $creds.Password
}

Write-Host "`nKész! Használathoz futtasd: wsl -d $selected" -ForegroundColor Green
