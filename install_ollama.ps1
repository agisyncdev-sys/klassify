$ErrorActionPreference = "Stop"

Write-Host "Step 1: Downloading Ollama Setup..."
Invoke-WebRequest -Uri "https://ollama.com/download/OllamaSetup.exe" -OutFile "$env:TEMP\OllamaSetup.exe"

Write-Host "Step 2: Installing Ollama silently..."
Start-Process -FilePath "$env:TEMP\OllamaSetup.exe" -ArgumentList "/S" -Wait -NoNewWindow

Write-Host "Step 3: Starting Ollama background service..."
# If it's already running, this might fail, so we catch it
try {
    Start-Process -FilePath "$env:LOCALAPPDATA\Programs\Ollama\ollama app.exe" -WindowStyle Hidden
} catch {
    Write-Host "Ollama might already be running."
}

# Give it a moment to boot up
Start-Sleep -Seconds 5

Write-Host "Step 4: Downloading the Gemma AI model (This will take a few minutes depending on internet speed)..."
& "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe" pull gemma

Write-Host "Done! The Local AI is now fully configured and running."
