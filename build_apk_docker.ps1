# Build the Docker image
Write-Host "Building Docker Image..."
docker build -t biztonic-pos-android -f Dockerfile.android .

# Create a temporary container
Write-Host "Creating Container..."
$containerId = docker create biztonic-pos-android

# Remove old APK if exists
if (Test-Path "app-release.apk") {
    Remove-Item "app-release.apk"
}

# Copy the APK out of the container
Write-Host "Extracting APK..."
docker cp ${containerId}:/app/build/app/outputs/flutter-apk/app-release.apk ./app-release.apk

# Cleanup
Write-Host "Cleaning up Container..."
docker rm $containerId

Write-Host "Done! APK saved to $(Get-Location)\app-release.apk"
