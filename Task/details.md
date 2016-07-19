# Build Visual Studio .NET 2003

A build task to build Visual Studio .NET 2003 applications (.NET 1.1). 

Even though this version of Visual Studio is [no longer supported by Microsoft](https://support.microsoft.com/en-us/lifecycle/search?sort=PN&alpha=Visual%20Studio) (and not even [.NET 1.1](https://support.microsoft.com/en-us/lifecycle/search?sort=pn&alpha=.net%20framework)), there are many enterprises that still have legacy applications that run in this platform. Probably are applications so stable that don't worth the migration effort or, maybe, the migration schedule are so long that an immediate build automation for the 2003 version is necessary.

The task builds Desktop Applications and also WebSites. The build process consists basically in call the Visual Studio 2003 application (DevEnv.exe) passing a solution file (\*.sln) or a project file (\*.\*proj) with the option '*/nologo*'.

To build websites though, as in Visual Studio 2003 web site projects has the dependency of a IIS website, the task does the following actions:
 1. Identifies in the solution file (or in the webinfo file, if a project file was informed) if exists a website project;
 2. For each website project identified: it creates a new temporary website in the local IIS Server, with a random port, using the default ASP.NET 1.1 Application Pool and the local path of the site pointing to the project files at the build workspace;
 3. For each web site project identified: it edits the build workspace version of the solution file and point the project url to the url of the website created. If it was informed a \*.\*proj file, the task will edit the corresponding webinfo file instead;
 4. So, the task will call 'DevEnv.exe' to build the solution (or project);  
 5. Finally, after the build was done, all the temporary websites are removed from the local IIS. 

The task requires the 'VS71COMNTOOLS' capability from the agent. This capability is normally available when Visual Studio 2003 is installed on the agent machine.  
