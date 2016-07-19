# Build Visual Studio .NET 2003
## Overview
The task is used to build Visual Studio .NET 2003 applications (.NET 1.1). Even though this version of Visual Studio is [no longer supported by Microsoft](https://support.microsoft.com/en-us/lifecycle/search?sort=PN&alpha=Visual%20Studio) (and not even [.NET 1.1](https://support.microsoft.com/en-us/lifecycle/search?sort=pn&alpha=.net%20framework)), there are many enterprises that still have legacy applications that run in this platform. Probably are applications so stable that don't worth the migration effort or, maybe, the migration schedule are so long that an immediate build automation for the 2003 version is necessary.

The task builds Desktop Applications and also WebSites. The build process consists basically in call the Visual Studio 2003 application (DevEnv.exe) passing a solution file (\*.sln) or a project file (\*.\*proj) with the option '*/nologo*'.

To build websites though, as in Visual Studio 2003 web site projects has the dependency of a IIS website, the task does the following actions:
 1. Identifies in the solution file (or in the webinfo file, if a project file was informed) if exists a website project;
 2. For each website project identified: it creates a new temporary website in the local IIS Server, with a random port, using the default ASP.NET 1.1 Application Pool and the local path of the site pointing to the project files at the build workspace;
 3. For each web site project identified: it edits the build workspace version of the solution file and point the project url to the url of the website created. If it was informed a \*.\*proj file, the task will edit the corresponding webinfo file instead;
 4. So, the task will call 'DevEnv.exe' to build the solution (or project);  
 5. Finally, after the build was done, all the temporary websites are removed from the local IIS. 

The task requires the 'VS71COMNTOOLS' capability from the agent. This capability is normally available when Visual Studio 2003 is installed on the agent machine.  

## Pre-requisites for the task
The following pre-requisites need to be set-up for the task work properly:

### Visual Studio 2003
You will need a version of Visual Studio .NET 2003 installed in the build agent machine. As the task calls the 'devenv.exe' command, it is made necessary.

### .NET framework 1.1 and all his updates
The VS2003 installation will also installs .NET 1.1 but it recommend that you install all the Service Pack 1 and the security update for the Service Pack 1.

Originally, Visual Studio 2003 was built for Windows Server 2003. But if you want to build in a newer version of Windows Server (2008 ou 2012), consult  [http://lifeofageekadmin.com/installing-net-11-windows-2008-r2](http://lifeofageekadmin.com/installing-net-11-windows-2008-r2/). In this case is mandatory to install SP1 and it's security update, to properly run a .NET 1.1 website on IIS7 or IIS8, and also other configuration steps. 

>Note: To build websites you will need that ASP.NET 1.1 websites properly runs in the IIS, because VS2003 website projects depends on it. So any error accessing the website on IIS will fail the build.   

I am successfully running the task on Windows Server 2012 R2 VM on Azure.


## Parameters of the task
These are the parameters necessary to use the task. Requeried parameters are hightlighted with a __*__:
- __TargetFile*__: Path to target files (solutions or projects) to be built. The default value is '*.sln', so it will look for all solutions file bellow the repository path informed.
- __Config*__: The configuration to build the application (debug, release).

### Advanced
The section provides advanced options:
- **DevEnvPath**: Agent full path to Microsoft Visual Studio 2003 'DevEnv.exe' file. If not informed, the agent will search for a 'VS71COMNTOOLS' enviroment variable. If it wasn't defined, the build will fail. The default value is 'C:\\Program Files (x86)\\Microsoft Visual Studio .NET 2003\\Common7\\IDE\\Devenv.exe' which is also the default installation path of VS2003.
- **AppPoolName**: Application Pool to be used with the websites created to build webprojects. If not informed, the build will create a temporary application pool for each website. Important: the application pool identity needs to have permissions on the agent source directory. The default value is 'ASP.NET 1.1' that is the application pool created when you install .NET 1.1.

## Known Issues
Normally when you install Visual Studio 2003 the environment variable 'VS71COMNTOOLS' is created, and so the agent automatically creates a capability for it.

The task rely on this capability to build. If, for any reason, this capability was not generated, you must manually create an user capability for 'VS71COMNTOOLS'.  The value for this user capability will depends on the following situations:
- If the advanced parameter **'DevEnvPath'** is informed, you can inform any value to 'VS71COMNTOOLS' capability, because the task will use the value of the parameter;
- But, if the advanced parameter **'DevEnvPath'** is blank, you must inform the path to the parent folder of 'devenv.exe' file, or the build will fail because it will not find 'devenv.exe' file.  