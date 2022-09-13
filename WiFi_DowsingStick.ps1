###
### WiFi Dowsing Stick
### https://github.com/johanabr/Powershell
### 
### Continually parses NETSH-output to easily discern AP-connectivity while moving around with a laptop.
### Distribute locally to a troubleshooting user - don't run from a network share (for obvious reasons).
### Right click and select "Run with powershell". Does not require admin privileges.
### Ping drops are indicated with red text and AP-changes are indicated with yellow text.
###
$VERSION = "v 1.5"

$Log = "$PSScriptRoot\wifilog.txt"
$date = Get-Date -Format yyyyMMdd-HHmmss
if (get-item $log -ErrorAction SilentlyContinue) {Rename-item $log wifilog_$date.txt}
Add-Content $log "Starting script $date"

Write-Host "WiFi Dowsing Stick $VERSION" -ForegroundColor Gray
Write-Host "For newest version visit https://github.com/johanabr/Powershell `n`n" -ForegroundColor Gray
Write-Host "Ping drops are indicated with red text" -ForegroundColor Red
Write-host "AP-changes are indicated with yellow text." -ForegroundColor Yellow
Write-Host "Press Control-C to cancel `n`n"
Start-Sleep 3

$networkadapter = (Get-NetAdapter | Where-Object {$_.PhysicalMediaType -like "*802*" -and $_.Status -eq "Up"}) 
if ($networkadapter.count -gt 1)
    {
    Write-Host "Multiple network connections active. Aborting script." -ForegroundColor Red
    $networkadapter
    Write-Host ""
    Write-Host "Disconnect Ethernet-cable and try again." -ForegroundColor Red
    Break
    }
else 
    {
    $wifiadapter = ($networkadapter | Where-Object {$_.PhysicalMediaType -like "*802.1*" -and $_.status -eq "Up"})
    $wifiindex = $wifiadapter.ifIndex
    $MAC = $wifiadapter.macaddress
    } 
if (!$MAC)
    {
    Write-Host "No WiFi-connection found." -ForegroundColor Red
    $networkadapter
    Write-Host ""
    Write-Host "Check adapter configuration and try again" -ForegroundColor Red
    Break
    }
else {$gateway = ((Get-NetIPConfiguration | Where-Object {$_.interfaceindex -eq $wifiindex}).IPv4DefaultGateway).NextHop}

$output = "Client Gateway: $gateway ($($wifiadapter.ifdesc)) | Client WiFi MAC: $MAC | Client name: $env:COMPUTERNAME" 
Write-Host "$output `n`n" -ForegroundColor Green
Add-Content $log $output

while ($date) # I.e. loop forever
    { 
    $time = Get-Date -Format HH:mm:ss.ff
    $netsh = netsh wlan show interfaces
    $ping = ping $gateway -n 1
    $netsh = $netsh.split("`n")

    foreach ($row in $netsh) # Netsh-parsing
        {
        $row = $row.TrimStart()
        if ($row -like "SSID*"){$SSID = $row.split(":")[1].trimstart()}
        if ($row -like "BSSID*") # BSSID gets special treatment to notify if changed from previous loop. Splits differently because of multiple insatnces of ":"
            {
            $bssid = ($row -split ":",2)[1].TrimStart().toupper()
            if ($prevbssid)
                {
                if ($bssid -ne $prevbssid){$change = $true}
                else {$change = $false}
                }
            if ($bssid) {$prevbssid = $bssid}
            }
        if ($row -like "Band*"){$band = $row.split(":")[1].trimstart()}
        if ($row -like "Channel*"){$Channel = $row.split(":")[1]}
        if ($row -like "Signal*"){$Signal = $row.split(":")[1]}
        if ($row -like "Authentication*"){$Auth = $row.split(":")[1].trimstart()}
        if ($row -like "Cipher*"){$Cipher = $row.split(":")[1].trimstart()}
        if ($row -like "Transmit rate*"){$transmit = $row.split(":")[1]}
        if ($row -like "Receive rate*"){$recieve = $row.split(":")[1]}
        if ($row -like "State*"){$state = $row.split(":")[1]}
        }

    if (($ping)[2] -like "*reply*") {$response = $ping[2].split("=").split(">").split("<")[2].trimend(" TTL")} # Ping response-parsing
    else {$response = $false}

    if ($state -notlike "*disconnected*") 
        {
        $output = "Connected to $SSID ($bssid) - PING: $response [ Signal: $signal | CH:$channel ($band) | R:$recieve (Mbps) / S:$transmit (Mbps) | $auth ($Cipher) ] - Time: $time"
        if ($change -eq $true) {Write-Host $output -ForegroundColor Yellow}
        elseif ($response -eq $false) {Write-Host $output -ForegroundColor Red}
        else {Write-Host $output}
        }
    else
        {
        $status = (Get-NetAdapter -InterfaceIndex $wifiindex).Status
        $output = "Not connected to WiFi (Interface Status: $status) - $time"
        Write-Host $output -ForegroundColor Gray
        }
    Add-Content $log $output
    Start-Sleep 1 # Wait one second until loop repeats
    }