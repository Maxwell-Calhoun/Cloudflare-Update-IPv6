# config
$apiToken = "YOUR_API_TOKEN"
$zoneId = "YOUR_ZONE_ID"
$recordId = "YOUR_RECORD_ID"
$dnsName = @("example.com", "www.example.com") # Add your DNS names here

# get global ipv6
$ipv6 = (Get-NetIPAddress -AddressFamily IPv6 | Where-Object {
    $_.PrefixOrigin -eq "Dhcp" -and $_.Address -notlike "fe80*"
}).IPAddress | Select-Object -First 1

if (-not $ipv6) {
    Write-Host "No global IPv6 found."
    exit 1
}

# get current record
$headers = @{ Authorization = "Bearer $apiToken"; "Content-Type" = "application/json" }
$recordUrl = "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records/$recordId"
$current = Invoke-RestMethod -Uri $recordUrl -Headers $headers -Method GET

if ($current.result.content -ne $ipv6) {
    Write-Host "🔁 Updating Cloudflare record..."
    $body = @{
        type    = "AAAA"
        name    = $dnsName
        content = $ipv6
        ttl     = 60
        proxied = $false
    } | ConvertTo-Json -Depth 2

    Invoke-RestMethod -Uri $recordUrl -Headers $headers -Method PUT -Body $body
    Write-Host "✅ Updated AAAA to $ipv6"
} else {
    Write-Host "✔️ No change needed"
}
