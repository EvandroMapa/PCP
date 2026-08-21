$url = 'https://aumfedyfrxuwgkdhwrel.supabase.co'
$key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8'
$headers = @{
    'apikey'        = $key
    'Authorization' = "Bearer $key"
}

Write-Host "--- DETALHES DOS STEPS ---" -ForegroundColor Cyan
$steps = Invoke-RestMethod -Uri "$url/rest/v1/steps?id=in.(tn52LXmuMwqETFbLqyvMCLxUH,uFJ3S0dZmctuzEkImApVs58JD)&select=*" -Headers $headers
$steps | ConvertTo-Json -Depth 5
