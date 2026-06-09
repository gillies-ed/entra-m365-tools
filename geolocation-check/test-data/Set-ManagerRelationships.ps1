<#
.SYNOPSIS
    Sets manager relationships in the <enter_your_domain_here>.onmicrosoft.com dev tenant.

.DESCRIPTION
    One-time setup script. Connects to Microsoft Graph and assigns managers
    to all test users so that Get-MgUserManager returns real data during
    end-to-end testing of the Geo Location Report Viewer.

    Org structure:
        Patti Fernandez          (no manager — top of org)
        ├── Megan Bowen
        │   ├── Adele Vance
        │   ├── Alex Wilber
        │   └── Joni Sherman
        ├── Miriam Graham
        │   ├── Grady Archie
        │   ├── Isaiah Langer
        │   └── Lee Gu
        ├── Nestor Wilke
        │   ├── Diego Siciliani
        │   ├── Henrietta Mueller
        │   ├── Johanna Lorenz
        │   ├── Lidia Holloway
        │   ├── Lynne Robbins
        │   └── Pradeep Gupta
        └── Ed Gillies (IT admin)

.NOTES
    Requirements:
        Install-Module Microsoft.Graph -Scope CurrentUser
    Permissions (delegated):
        User.ReadWrite.All  — needed to set manager relationships
#>

[CmdletBinding(SupportsShouldProcess)]
param()

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║      Dev Tenant Manager Setup  v1.0                     ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ── Connect ───────────────────────────────────────────────────────────────────
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -ClientId '<YOUR-CLIENT-ID>' -TenantId '<YOUR-TENANT-ID>' -Scopes 'User.ReadWrite.All' -NoWelcome -ErrorAction Stop
Write-Host "Connected.`n" -ForegroundColor Green

# ── Resolve UPNs to object IDs ────────────────────────────────────────────────
Write-Host "Resolving user object IDs..." -ForegroundColor Cyan

$upns = @(
    'PattiF@<enter_your_domain_here>.onmicrosoft.com',
    'MeganB@<enter_your_domain_here>.onmicrosoft.com',
    'MiriamG@<enter_your_domain_here>.onmicrosoft.com',
    'NestorW@<enter_your_domain_here>.onmicrosoft.com',
    'LynneR@<enter_your_domain_here>.onmicrosoft.com',
    'AdeleV@<enter_your_domain_here>.onmicrosoft.com',
    'AlexW@<enter_your_domain_here>.onmicrosoft.com',
    'JoniS@<enter_your_domain_here>.onmicrosoft.com',
    'GradyA@<enter_your_domain_here>.onmicrosoft.com',
    'IsaiahL@<enter_your_domain_here>.onmicrosoft.com',
    'LeeG@<enter_your_domain_here>.onmicrosoft.com',
    'DiegoS@<enter_your_domain_here>.onmicrosoft.com',
    'HenriettaM@<enter_your_domain_here>.onmicrosoft.com',
    'JohannaL@<enter_your_domain_here>.onmicrosoft.com',
    'LidiaH@<enter_your_domain_here>.onmicrosoft.com',
    'LynneR@<enter_your_domain_here>.onmicrosoft.com',
    'PradeepG@<enter_your_domain_here>.onmicrosoft.com'
)

$users = @{}
foreach ($upn in $upns) {
    try {
        $u = Get-MgUser -UserId $upn -Property Id, DisplayName, UserPrincipalName -ErrorAction Stop
        $users[$upn.ToLower()] = $u
        Write-Host "  OK  $($u.DisplayName)" -ForegroundColor Green
    }
    catch {
        Write-Host "  SKIP $upn — not found" -ForegroundColor Yellow
    }
}

# ── Manager assignments ───────────────────────────────────────────────────────
# Format: @{ User = 'upn'; Manager = 'upn' }
$assignments = @(
    @{ User = 'MeganB@<enter_your_domain_here>.onmicrosoft.com';     Manager = 'PattiF@<enter_your_domain_here>.onmicrosoft.com' },
    @{ User = 'MiriamG@<enter_your_domain_here>.onmicrosoft.com';    Manager = 'PattiF@<enter_your_domain_here>.onmicrosoft.com' },
    @{ User = 'NestorW@<enter_your_domain_here>.onmicrosoft.com';    Manager = 'PattiF@<enter_your_domain_here>.onmicrosoft.com' },
    @{ User = 'LynneR@<enter_your_domain_here>.onmicrosoft.com'; Manager = 'PattiF@<enter_your_domain_here>.onmicrosoft.com' },
    @{ User = 'AdeleV@<enter_your_domain_here>.onmicrosoft.com';     Manager = 'MeganB@<enter_your_domain_here>.onmicrosoft.com' },
    @{ User = 'AlexW@<enter_your_domain_here>.onmicrosoft.com';      Manager = 'MeganB@<enter_your_domain_here>.onmicrosoft.com' },
    @{ User = 'JoniS@<enter_your_domain_here>.onmicrosoft.com';      Manager = 'MeganB@<enter_your_domain_here>.onmicrosoft.com' },
    @{ User = 'GradyA@<enter_your_domain_here>.onmicrosoft.com';     Manager = 'MiriamG@<enter_your_domain_here>.onmicrosoft.com' },
    @{ User = 'IsaiahL@<enter_your_domain_here>.onmicrosoft.com';    Manager = 'MiriamG@<enter_your_domain_here>.onmicrosoft.com' },
    @{ User = 'LeeG@<enter_your_domain_here>.onmicrosoft.com';       Manager = 'MiriamG@<enter_your_domain_here>.onmicrosoft.com' },
    @{ User = 'DiegoS@<enter_your_domain_here>.onmicrosoft.com';     Manager = 'NestorW@<enter_your_domain_here>.onmicrosoft.com' },
    @{ User = 'HenriettaM@<enter_your_domain_here>.onmicrosoft.com'; Manager = 'NestorW@<enter_your_domain_here>.onmicrosoft.com' },
    @{ User = 'JohannaL@<enter_your_domain_here>.onmicrosoft.com';   Manager = 'NestorW@<enter_your_domain_here>.onmicrosoft.com' },
    @{ User = 'LidiaH@<enter_your_domain_here>.onmicrosoft.com';     Manager = 'NestorW@<enter_your_domain_here>.onmicrosoft.com' },
    @{ User = 'LynneR@<enter_your_domain_here>.onmicrosoft.com';     Manager = 'NestorW@<enter_your_domain_here>.onmicrosoft.com' },
    @{ User = 'PradeepG@<enter_your_domain_here>.onmicrosoft.com';   Manager = 'NestorW@<enter_your_domain_here>.onmicrosoft.com' }
)

Write-Host "`nSetting manager relationships..." -ForegroundColor Cyan
$ok = 0; $fail = 0

foreach ($a in $assignments) {
    $userKey    = $a.User.ToLower()
    $managerKey = $a.Manager.ToLower()

    $userObj    = $users[$userKey]
    $managerObj = $users[$managerKey]

    if (-not $userObj -or -not $managerObj) {
        Write-Host "  SKIP  $($a.User) — user or manager not resolved" -ForegroundColor Yellow
        $fail++
        continue
    }

    $managerRef = @{
        '@odata.id' = "https://graph.microsoft.com/v1.0/users/$($managerObj.Id)"
    }

    try {
        Set-MgUserManagerByRef -UserId $userObj.Id -BodyParameter $managerRef -ErrorAction Stop
        Write-Host "  SET   $($userObj.DisplayName) → $($managerObj.DisplayName)" -ForegroundColor Green
        $ok++
    }
    catch {
        Write-Host "  FAIL  $($userObj.DisplayName): $_" -ForegroundColor Red
        $fail++
    }
}

Write-Host ""
Write-Host "Done.  Set: $ok   Failed/skipped: $fail" -ForegroundColor Cyan
Write-Host ""
