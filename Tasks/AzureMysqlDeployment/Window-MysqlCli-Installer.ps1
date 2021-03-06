################################################################################
##  File:  Install-MysqlCli.ps1
##  Team:  ReleaseManagement
##  Desc:  Install Mysql CLI
################################################################################

# Install exe through url 
function Install-EXE
{
    Param
    (
        [String]$Url,
        [String]$Name,
        [String[]]$ArgumentList
    )

    $exitCode = -1

    try
    {
        Write-Host "Downloading $Name..."
        $FilePath = "${env:Temp}\$Name"

        Invoke-WebRequest -Uri $Url -OutFile $FilePath

        Write-Host "Starting Install $Name..."
        $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -Wait -PassThru
        $exitCode = $process.ExitCode

        if ($exitCode -eq 0 -or $exitCode -eq 3010)
        {
            Write-Host -Object 'Installation successful'
            return $exitCode
        }
        else
        {
            Write-Host -Object "Non zero exit code returned by the installation process : $exitCode."
            return $exitCode
        }
    }
    catch
    {
        Write-Host -Object "Failed to install the Executable $Name"
        Write-Host -Object $_.Exception.Message
        return -1
    }
}

function ExtractFiles
{
    <#
        .DESCRIPTION
        Extracts the zip file to the location provided.
        It uses the latest command 'Expand-Archive' if available otherwise it fallsback to shell for extraction
        .PARAMETER ZipPath
        Path of the zip file to extract.
        
        .PARAMETER DestinationPath
        Directory where the zip file needs to be extracted        
    #>
    [CmdletBinding()]
    Param
    (
        [string]$ZipPath,
        [string]$DestinationPath
    )

    try
    {
        if (-not (Test-Path $ZipPath))
        {
            Write-Host "$ZipPath does not exist."
            return
        }

        if (-not (Test-Path $DestinationPath))
        {
            New-Item -Type Directory $DestinationPath
        }

        $zipFullPath = [System.IO.Path]::GetFullPath($ZipPath)
        Write-Host "Extracting $zipFullPath to path: $DestinationPath"
        if (Get-Command Expand-Archive -ErrorAction SilentlyContinue)
        {
            Expand-Archive $zipFullPath $DestinationPath -Force
        }
        else 
        {
            $shellApplication = New-Object -ComObject Shell.Application
            if ($shellApplication -eq $null)
            {
                Write-Host 'Unable to create Shell.'
                exit  
            }            
            
            $zipPackage = $shellApplication.NameSpace($zipFullPath)
            if ($zipPackage -eq $null)
            {
                Write-Host 'Unable to create shell zipPackage.'
                exit
            }

            $destinationFolder = $shellApplication.NameSpace($DestinationPath) 

            # CopyHere Flags 
            # 4 - Do not display a progress dialog box. 
            # 16 - Respond with "Yes to All" for any dialog box that is displayed. 

            $destinationFolder.CopyHere($zipPackage.Items(),20)       
        }
    }
    catch
    {
        Write-Host $_.Exception.Message
        exit
    }
}

# Set new machine path 
function Set-MachinePath{
    [CmdletBinding()]
    param(
        [string]$NewPath
    )
    Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name Path -Value $NewPath
    return $NewPath
}

# Get machine path from registry
function Get-MachinePath{
    [CmdletBinding()]
    param(

    )
    $currentPath = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).Path
    return $currentPath
}

# Append path of exe in existing path
function Add-MachinePathItem
{
    [CmdletBinding()]
    param(
        [string]$PathItem
    )

    $currentPath = Get-MachinePath
    $newPath = $PathItem + ';' + $currentPath
    return Set-MachinePath -NewPath $newPath
}

## Downloading mysql jar
$uri = 'https://dev.mysql.com/get/Downloads/MySQL-5.7/mysql-5.7.21-winx64.zip'
$mysqlPath = 'C:\mysql-5.7.21-winx64\bin'

# Installing visual c++ redistibutable package.
$InstallerURI = 'http://download.microsoft.com/download/0/5/6/056dcda9-d667-4e27-8001-8a0c6971d6b1/vcredist_x64.exe'
$InstallerName = 'vcredist_x64.exe'
$ArgumentList = ('/install', '/quiet', '/norestart' )

$exitCode = Install-EXE -Url $InstallerURI -Name $InstallerName -ArgumentList $ArgumentList
if ($exitCode -eq 0 -or $exitCode -eq 3010)
{
    # Get the latest mysql command line tools .
    Invoke-WebRequest -UseBasicParsing -Uri $uri -OutFile mysql.zip

    # Expand the zip
    $pwdPath = $pwd.Path
    if ( $pwdPath -notmatch '.+?\\$')
    {
    	$pwdPath += '\'
    }
    $sourcePath = $pwdPath + "mysql.zip"
    ExtractFiles  $sourcePath "C:\"

    # Deleting zip folder
    Remove-Item -Recurse -Force mysql.zip

    # Adding mysql in system environment path
    Add-MachinePathItem $mysqlPath

    return 0;
}
else
{
    return $exitCode;
}