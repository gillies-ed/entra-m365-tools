<#
.SYNOPSIS
    Geo Location Report Viewer v2 — starts a local web server.

.DESCRIPTION
    Serves the Geo Location Report Viewer on localhost and handles Microsoft Graph
    API calls for line manager lookups.

    No connection to Microsoft Graph or Entra ID is made until the user clicks
    "Get Line Managers" in the browser.

.PARAMETER Port
    TCP port for the local web server. Default: 8765.

.PARAMETER LlmEndpoint
    Base URL for an OpenAI-compatible LLM API used to generate narratives.
    Default: http://localhost:11434/v1 (Ollama default)
    Set to an empty string to disable the Narratives feature.

.PARAMETER ClientId
    Azure AD application (client) ID for Microsoft Graph authentication.
    Required to use the "Get Line Managers" feature.
    Register an app in Entra ID with delegated User.Read.All permission.

.PARAMETER TenantId
    Azure AD tenant ID (directory ID) for Microsoft Graph authentication.
    Required to use the "Get Line Managers" feature.

.EXAMPLE
    .\Start-GeoLocationViewer.ps1
    .\Start-GeoLocationViewer.ps1 -Port 9000
    .\Start-GeoLocationViewer.ps1 -ClientId 'your-app-id' -TenantId 'your-tenant-id'
    .\Start-GeoLocationViewer.ps1 -LlmEndpoint 'http://localhost:11434/v1'

.NOTES
    Author  : Ed Gillies
    Project : https://github.com/EdGillies/geolocation-check

    Requirements:
        Microsoft.Graph PowerShell module (for Get Line Managers feature)
        Install-Module Microsoft.Graph -Scope CurrentUser

    Permissions (delegated, requested only when Get Line Managers is clicked):
        User.Read.All
#>

[CmdletBinding()]
param(
    [int]$Port        = 8765,
    [string]$LlmEndpoint = 'http://localhost:11434/v1',
    [string]$ClientId    = '',
    [string]$TenantId    = ''
)

$script:LlmEndpoint = $LlmEndpoint.TrimEnd('/')
$script:ClientId    = $ClientId
$script:TenantId    = $TenantId

#region ── Banner ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║      Geo Location Report Viewer  v2.0                   ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
#endregion

#region ── Dependency check ───────────────────────────────────────────────────
$requiredModules = @('Microsoft.Graph.Authentication', 'Microsoft.Graph.Users')
$missingModules  = $requiredModules | Where-Object { -not (Get-Module -Name $_ -ListAvailable) }

if ($missingModules) {
    Write-Host "WARNING: Missing PowerShell module(s) — Get Line Managers will be unavailable:" -ForegroundColor Yellow
    $missingModules | ForEach-Object { Write-Host "         - $_" -ForegroundColor Yellow }
    Write-Host ""
    Write-Host "       Install with:" -ForegroundColor DarkGray
    Write-Host "         Install-Module Microsoft.Graph -Scope CurrentUser" -ForegroundColor DarkGray
    Write-Host ""
}
else {
    Write-Host "Required modules found." -ForegroundColor Green
}
#endregion

#region ── Locate HTML file ───────────────────────────────────────────────────
$htmlPath = Join-Path $PSScriptRoot "geo-report-viewer.html"

if (-not (Test-Path $htmlPath)) {
    Write-Host "ERROR: geo-report-viewer.html not found at: $htmlPath" -ForegroundColor Red
    exit 1
}
#endregion

#region ── HTTP helpers ───────────────────────────────────────────────────────
function Send-Response {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [int]$StatusCode     = 200,
        [string]$ContentType = 'text/plain; charset=utf-8',
        [string]$Body        = ''
    )
    $Response.StatusCode = $StatusCode
    $Response.ContentType = $ContentType
    $Response.Headers.Add('Cache-Control', 'no-cache')
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
    $Response.ContentLength64 = $bytes.Length
    $Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $Response.OutputStream.Close()
}

function Read-RequestBody {
    param([System.Net.HttpListenerRequest]$Request)
    $reader = New-Object System.IO.StreamReader($Request.InputStream, [System.Text.Encoding]::UTF8)
    return $reader.ReadToEnd()
}
#endregion

#region ── Graph manager lookup ───────────────────────────────────────────────
$script:graphConnected = $false
$script:managerCache   = @{}

function Get-ManagerData {
    param([string[]]$Upns)

    if (-not $script:ClientId -or -not $script:TenantId) {
        throw "ClientId and TenantId are required for manager lookup. Run the script with -ClientId and -TenantId parameters."
    }

    # Connect to Graph on first call only — this is where browser auth happens
    if (-not $script:graphConnected) {
        Write-Host ""
        Write-Host "── Connecting to Microsoft Graph ───────────────────────────" -ForegroundColor Cyan
        Write-Host "   A browser window will open — sign in with your Entra admin account."
        Connect-MgGraph -ClientId $script:ClientId -TenantId $script:TenantId -Scopes 'User.Read.All' -NoWelcome -ErrorAction Stop
        $script:graphConnected = $true
        Write-Host "   Connected successfully." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "── Looking up managers ─────────────────────────────────────────" -ForegroundColor Cyan

    $results = [ordered]@{}
    $i = 0

    foreach ($upn in $Upns) {
        $i++

        if ($script:managerCache.ContainsKey($upn)) {
            $results[$upn] = $script:managerCache[$upn]
            Write-Host "  [$i/$($Upns.Count)] $upn (cached)" -ForegroundColor DarkGray
            continue
        }

        Write-Host "  [$i/$($Upns.Count)] $upn ..." -NoNewline

        try {
            $mgr     = Get-MgUserManager -UserId $upn -ErrorAction Stop
            $mgrUser = Get-MgUser -UserId $mgr.Id -Property DisplayName, UserPrincipalName -ErrorAction Stop
            $entry   = [ordered]@{ managerName = $mgrUser.DisplayName; managerUpn = $mgrUser.UserPrincipalName }
            Write-Host " $($mgrUser.DisplayName)" -ForegroundColor Green
        }
        catch {
            $entry = [ordered]@{ managerName = 'No manager found'; managerUpn = '' }
            Write-Host " no manager found — $_" -ForegroundColor Yellow
        }

        $script:managerCache[$upn] = $entry
        $results[$upn] = $entry
    }

    return $results
}
#endregion

#region ── LLM narrative ──────────────────────────────────────────────────────
function Get-LlmNarrative {
    param([PSCustomObject]$Data)

    if (-not $script:LlmEndpoint) {
        throw "LLM endpoint not configured. Run the script with -LlmEndpoint to enable narratives."
    }

    $name = $Data.name

    $eventLines = $Data.events | ForEach-Object {
        $dt  = try { [datetime]$_.time } catch { $null }
        $ts  = if ($dt) { $dt.ToString('dd MMM HH:mm') } else { $_.time }
        $loc = (@($_.city, $_.state, $_.country) | Where-Object { $_ }) -join ', '
        "- $ts — $loc ($($_.app))"
    }

    $prompt  = "You are a concise security analyst. Write a 2-3 sentence plain-English summary for a line manager "
    $prompt += "about the following Microsoft Entra sign-in activity for $name this week.`n`n"
    $prompt += "Non-UK sign-ins:`n" + ($eventLines -join "`n")

    $itList = @($Data.impossibleTravel)
    if ($itList.Count -gt 0) {
        $prompt += "`n`nIMPORTANT — impossible travel detected:`n"
        foreach ($it in $itList) {
            $dH = [math]::Round($it.deltaH, 1)
            $mH = [math]::Round($it.minH,   1)
            $fc = $it.fromCountry; if ($it.fromCity) { $fc += " ($($it.fromCity))" }
            $tc = $it.toCountry;   if ($it.toCity)   { $tc += " ($($it.toCity))"   }
            $prompt += "- Signed in from $fc then $tc only ${dH}h later (minimum ~${mH}h travel time)`n"
        }
        $prompt += "Flag this as requiring urgent follow-up."
    }

    $prompt += "`n`nBe factual and concise. No bullet points. Address the manager directly."

    $llmBody = @{
        model       = 'local'
        messages    = @( @{ role = 'user'; content = $prompt } )
        max_tokens  = 250
        temperature = 0.3
    } | ConvertTo-Json -Depth 5 -Compress

    Write-Host "  Generating narrative for $name ..." -NoNewline

    $resp      = Invoke-RestMethod -Uri "$script:LlmEndpoint/chat/completions" `
                                   -Method POST `
                                   -ContentType 'application/json; charset=utf-8' `
                                   -Body $llmBody `
                                   -ErrorAction Stop
    $narrative = $resp.choices[0].message.content.Trim()

    Write-Host " done." -ForegroundColor Green
    return $narrative
}
#endregion

#region ── Start HTTP listener ────────────────────────────────────────────────
$url      = "http://localhost:$Port/"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($url)

try {
    $listener.Start()
}
catch {
    Write-Host "ERROR: Could not bind to port $Port." -ForegroundColor Red
    Write-Host "       The server may already be running — try: $url" -ForegroundColor Yellow
    Write-Host "       Or use a different port: .\Start-GeoLocationViewer.ps1 -Port 9000" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Viewer running at $url" -ForegroundColor Green
Write-Host "Opening browser..." -ForegroundColor DarkGray
Write-Host "Press Ctrl+C to stop." -ForegroundColor DarkGray
Write-Host ""

Start-Process $url
#endregion

#region ── Request loop ───────────────────────────────────────────────────────
try {
    while ($listener.IsListening) {

        $context = $null
        try {
            $context = $listener.GetContext()
        }
        catch [System.Net.HttpListenerException] {
            break   # listener was stopped (Ctrl+C)
        }

        $req    = $context.Request
        $res    = $context.Response
        $method = $req.HttpMethod
        $path   = $req.Url.AbsolutePath

        Write-Host "  $method $path" -ForegroundColor DarkGray

        # ── OPTIONS preflight ──────────────────────────────────────────────
        if ($method -eq 'OPTIONS') {
            $res.Headers.Add('Access-Control-Allow-Origin',  '*')
            $res.Headers.Add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
            $res.Headers.Add('Access-Control-Allow-Headers', 'Content-Type')
            $res.StatusCode = 204
            $res.OutputStream.Close()
            continue
        }

        switch ("$method $path") {

            # ── Serve HTML ─────────────────────────────────────────────────
            'GET /' {
                $html = Get-Content -Path $htmlPath -Raw -Encoding UTF8
                Send-Response -Response $res -ContentType 'text/html; charset=utf-8' -Body $html
            }

            # ── Manager lookup ─────────────────────────────────────────────
            'POST /api/managers' {
                try {
                    $body = Read-RequestBody -Request $req
                    $upns = @($body | ConvertFrom-Json)

                    if ($upns.Count -eq 0) {
                        Send-Response -Response $res -StatusCode 400 -ContentType 'application/json' `
                            -Body '{"success":false,"error":"No UPNs provided"}'
                        continue
                    }

                    $managers = Get-ManagerData -Upns $upns
                    $payload  = [ordered]@{ success = $true; managers = $managers } | ConvertTo-Json -Depth 5
                    Send-Response -Response $res -ContentType 'application/json' -Body $payload
                }
                catch {
                    $errText = $_.ToString() -replace '[\r\n"\\]', ' '
                    Send-Response -Response $res -StatusCode 500 -ContentType 'application/json' `
                        -Body "{`"success`":false,`"error`":`"$errText`"}"
                }
            }

            # ── LLM narrative ──────────────────────────────────────────────
            'POST /api/llm-summary' {
                try {
                    $body    = Read-RequestBody -Request $req
                    $data    = $body | ConvertFrom-Json
                    $narrative = Get-LlmNarrative -Data $data
                    $payload   = @{ success = $true; narrative = $narrative } | ConvertTo-Json
                    Send-Response -Response $res -ContentType 'application/json' -Body $payload
                }
                catch {
                    $errText = $_.ToString() -replace '[\r\n"\\]', ' '
                    Send-Response -Response $res -StatusCode 500 -ContentType 'application/json' `
                        -Body "{`"success`":false,`"error`":`"$errText`"}"
                }
            }

            # ── 404 ───────────────────────────────────────────────────────
            default {
                Send-Response -Response $res -StatusCode 404 -Body 'Not found'
            }
        }
    }
}
finally {
    $listener.Stop()
    Write-Host ""
    Write-Host "Server stopped." -ForegroundColor DarkGray
}
#endregion
