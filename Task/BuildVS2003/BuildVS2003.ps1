Param (
		 [Parameter(mandatory=$true)]
         [string] $TargetFile,
         [Parameter(mandatory=$true)]
         [string] $Config,
	     [string] $DevEnvPath,
		 [string] $AppPoolName
)

import-module "Microsoft.TeamFoundation.DistributedTask.Task.Internal"
import-module "Microsoft.TeamFoundation.DistributedTask.Task.Common"

$buildSourcesDirectory = Get-TaskVariable -Context $distributedTaskContext -Name "Build.SourcesDirectory"

if (!$DevEnvPath)
{
	if ($env:VS71COMNTOOLS)
	{
		$DevEnvPath = $env:VS71COMNTOOLS
	}
	else
	{
		throw ("Invalid Microsoft Visual Studio 2003 DevEnv.exe path! Please inform a valid path or configure a ""VS71COMNTOOLS"" system enviroment variable with the path on the agent machine.")
	}
}

Function CreateLogFile($logPath) 
{
     if (Test-Path $logPath)
     {
         Remove-Item $logPath
     }
     $path = [IO.Path]::GetFullPath($logPath)
     New-Item -ItemType file  $path
}

Function Get-FileEncoding( [string] $FilePath )
{
    $sr = New-Object System.IO.StreamReader($FilePath, $true)
    [char[]] $buffer = new-object char[] 3
    $readcount = $sr.Read($buffer, 0, 3) 
    $encoding = $sr.CurrentEncoding
    $sr.Close()
    return $encoding
}

Function CreateWebSite([string] $siteName, [string] $physicalPath )
{
	$port = Get-Random -Minimum 35000 -Maximum 36000
	$siteUrl = "http://localhost:$port"

	if (!$AppPoolName)
	{
		#create Application Pool
		$AppPoolName = $siteName
    	$appPool = New-WebAppPool -Name $AppPoolName
		if($appPool.State -ne "Started")
		{
			Remove-WebAppPool -Name $AppPoolName
			throw (("Fail to start the application pool {0}. AppPool detais - Name: {1}, State: {2}. The AppPool will be removed." -f $AppPoolName, $appPool.Name, $appPool.State))
		}

		#Grant Application Pool Identity full control at website physical path
		$acl = Get-Acl "$physicalPath"
		$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("IIS APPPOOL\$AppPoolName","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
		$acl.AddAccessRule($rule)
		Set-Acl "$physicalPath" $acl

		Write-Host ("The application pool {0} was created to be used by the site {1}." -f $AppPoolName, $siteUrl)
	}
	
	$result = New-Website -Name "$siteName" -Port $port -PhysicalPath "$physicalPath" -ApplicationPool "$AppPoolName"
	
	if($result.State -ne "Started")
	{
		Remove-Website -Name $siteName
		throw (("Fail to start the Website {0}. Website detais - Name: {1}, State: {2}, Bindings: {3}, Physical Path: {4}. The website will be removed." -f $siteName, $result.Name, $result.State, $result.Bindings, $result.PhysicalPath))
	}

	return $siteUrl
}

Function HandleSolutionFile([string] $targetPath)
{
	$webSites = @()

	$matches = @()	
	$matches += Select-String -Path $targetPath -Pattern "Project\((.)*http://" -AllMatches
	$matches += Select-String -Path $targetPath -Pattern "Project\((.)*https://" -AllMatches

	if ($matches)
	{
		$solutionContent = Get-Content $targetPath
		$parentFolderPath = Split-Path $targetPath -Parent 

		Write-Host ("{0} web project(s) file(s) found in {1}!" -f $matches.Length, $targetPath)
			
		foreach($match in $matches)
		{
			$values = ($matches -split '=')[1] -split ','
			$siteName = $values[0] -replace """","" #nome do projeto
			$oldsiteUrl = $values[1] #url do projeto
			$projFileName = $oldsiteUrl -replace """","" | Split-Path -Leaf
			$projFilePath = Get-ChildItem "$parentFolderPath\$projFileName" -Recurse
            $physicalPath = Split-Path $projFilePath -Parent

			$siteUrl = CreateWebSite -siteName $siteName -physicalPath $physicalPath
			$webSites += $siteName

			#update solution file content with the new site
			$solutionContent = $solutionContent -replace $oldsiteUrl, """$siteUrl/$projFileName"""

			Write-Host ("The website {0} was created to build {1}!" -f $siteUrl, $projFileName)
		}
		
        $solutionContent | Out-File $targetPath
	}
	else
	{
		Write-Host ("No web project files found!")
	}

	return $webSites
}

Function HandleProjFile([string] $targetPath)
{
	$siteName = ""
	$parentFolderPath = Split-Path $targetPath -Parent  
	$webinfoFiles = Get-ChildItem -Path "$parentFolderPath\*.webinfo"

	if ($webinfoFiles)
	{
        $webinfoFile = $webinfoFiles[0] #It must exist only one webinfo file, if not, take the first
		[xml] $webinfoContent = Get-Content $webinfoFile
		$oldsiteUrl = $webinfoContent.VisualStudioUNCWeb.Web.URLPath
		$projFile = Split-Path -Path $oldsiteUrl -Leaf
		$siteName = ($projFile -split '.', 0, "simplematch")[0]
		$siteUrl = CreateWebSite -siteName $siteName -physicalPath $parentFolderPath

		$webinfoContent.VisualStudioUNCWeb.Web.URLPath = "$siteUrl/$projFile"

		#Update the file with the modified content 
		$fileEncoding = Get-FileEncoding $webinfoFile          
		[IO.File]::WriteAllText($webinfoFile, $webinfoContent.OuterXml, $fileEncoding)	

		Write-Host ("{0} is a web project!" -f $projFile)
		Write-Host ("The website {0} was created to build {1}!" -f $siteUrl, $projFile)
	}
	else
	{
		Write-Host ("No web project files found!")
	}

	return $siteName
}

Function PrepareWebProjects([string]$targetPath)
{
	$webSites = @()

	Write-Host "Looking for web projects..."
	if ($targetPath.EndsWith(".sln"))
	{	
		$webSites += HandleSolutionFile $targetPath
	}
	else 
	{
		if ($targetPath.EndsWith(".csproj") -or ($targetPath.EndsWith(".vbproj")))
		{
			$webSites += HandleProjFile $targetPath
		}
		else
		{
			throw ("The target build file is not a solution or project file! Please inform a file in the correct format.")
		}
	}

	return $webSites
}

Function CleanWebProjects($webSites)
{
	foreach($site in $webSites)
	{
		if ($site)
		{
			Remove-Website -Name $site
			Write-Host ("The website {0} was deleted!" -f $site)
			if (!$AppPoolName)
			{
				Remove-WebAppPool -Name $site
				Write-Host ("The application pool {0} was deleted!" -f $site)
			}
		}
	}
}

Function Build([string] $targetPath)
{
	Write-Host ">>>>>>>>> Begin build >>>>>>>>>>"
	Write-Host "Building $targetPath..."

	$websites = PrepareWebProjects $targetPath    

	$parentFolderPath = Split-Path $targetPath -Parent        
    $log = "$parentFolderPath\build.log"
    CreateLogFile $log 
    
	$buildArgs = """$targetPath"" /build $Config /out ""$log"" /nologo"
    Invoke-Tool -Path $DevEnvPath -Arguments $buildArgs -Verbose
    Type $log 

	CleanWebProjects $websites
	Write-Host "<<<<<<<<< End build <<<<<<<<<<"
}



Write-Host "Searching for target files..."
$files = Get-ChildItem "$TargetFile" -Recurse
    
if ($files.Length -eq 0)
{
	throw ("The specified Target(s) File(s) was not found!")
}

if ($files.GetType().FullName -eq "System.Object[]")
{
	Write-Host ("{0} build target files found!" -f $files.Length)
}

$position = "."
foreach($file in $files)
{
	Write-Host "$position"
    Build $file.FullName
	$position += "."
}

