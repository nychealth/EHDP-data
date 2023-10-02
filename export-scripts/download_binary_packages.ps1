# set proxy
$proxy_url = "http://healthproxy.health.dohmh.nycnet:8080"

# Define the R packages you want to download
$rPackages = @("ggplot2", "dplyr", "lattice")

# set R version
$rVersion = 4.3

# Set the download directory
$downloadDirectory = "C:\Users\cgettings\Documents\R\win-library\$rVersion"

# Create the download directory if it doesn't exist
if (-not (Test-Path $downloadDirectory)) {
    New-Item -ItemType Directory -Path $downloadDirectory | Out-Null
}

# Loop through each R package and download the latest Windows binary
foreach ($package in $rPackages) {
    # Construct the download URL for the package
    $downloadUrl = "https://cran.r-project.org/bin/windows/contrib/$rVersion/$package.zip"
    
    # Define the output file path
    $outputFilePath = Join-Path $downloadDirectory "$package.zip"

    # Download the package
    Invoke-WebRequest -Uri $downloadUrl -OutFile $outputFilePath -Proxy $proxy_url -ProxyUseDefaultCredentials
}

# Install the downloaded packages
foreach ($package in $rPackages) {
    # Construct the Rscript command to install the package from the downloaded files
    $rscriptInstallCommand = "install.packages(file.path('$downloadDirectory', '$package.zip'), dependencies=TRUE, repos=NULL)"

    # Run Rscript to install the package
    Start-Process Rscript -ArgumentList "-e $rscriptInstallCommand" -NoNewWindow -Wait
}
