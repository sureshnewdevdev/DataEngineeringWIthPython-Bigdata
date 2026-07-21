$ErrorActionPreference = "Stop"

Write-Host "Checking Java..."
java -version

Write-Host "Checking Python..."
python --version

if (-not (Test-Path ".venv")) {
    python -m venv .venv
}

& .\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt

New-Item -ItemType Directory -Force -Path data\incoming_posts | Out-Null
New-Item -ItemType Directory -Force -Path checkpoint | Out-Null
New-Item -ItemType Directory -Force -Path output | Out-Null

Write-Host ""
Write-Host "Setup complete."
Write-Host "Activate with: .\.venv\Scripts\Activate.ps1"
Write-Host "Start with: python 01_rate_stream.py"

