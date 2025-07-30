# config
$apiToken = "YOUR_API_TOKEN" # Cloudflare api token with permissions to edit DNS records
$zoneId = "YOUR_ZONE_ID" # Cloudflare zone ID for your domain
$dns_Records = @("example.com", "www.example.com") # Add your DNS names here

# get global ipv6
$ipv6 = (Get-NetIPAddress -AddressFamily IPv6 | Where-Object {
    $_.PrefixOrigin -eq 'RouterAdvertisement' -and
    $_.SuffixOrigin -eq 'Link' -and
    $_.AddressState -eq 'Preferred' -and
    $_.InterfaceAlias -eq 'Ethernet' -and
    $_.IPAddress -notlike 'fe80*'
}).IPAddress | Select-Object -First 1

if (-not $ipv6) {
    Write-Host "No global IPv6 found."
    exit 1
}

# get current record
$headers = @{ Authorization = "Bearer $apiToken"; "Content-Type" = "application/json" }

foreach ($record in $dns_records) {
    $response = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records?type=AAAA&name=$record" `
    -Headers @{ Authorization = "Bearer $apiToken" } `
    -ContentType "application/json" `
    -Method Get
    
    $recordId = $response.result[0].id
    $dns_recordUrl = "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records/$recordId"
    $current = Invoke-RestMethod -Uri $dns_recordUrl -Headers $headers -Method GET

    if ($current.result.content -ne $ipv6) {
        Write-Host "🔁 Updating Cloudflare record..."
        $body = @{
            type    = "AAAA"
            name    = $record
            content = $ipv6
            ttl     = 60
            proxied = $false
        } | ConvertTo-Json -Depth 2

        Invoke-RestMethod -Uri $dns_recordUrl -Headers $headers -Method PUT -Body $body
        Write-Host "Updated AAAA to $ipv6"
    } else {
        Write-Host "No change needed"
    }

}

