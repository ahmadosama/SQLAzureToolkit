function fn_executeprocess
{
	param
	(
		[string]$filename, 
		[string]$arg,
		[string]$workingdir,
		[bool]$wait=$true
	)
	$pinfo = New-Object System.Diagnostics.ProcessStartInfo
	$pinfo.FileName = $filename
	$pinfo.RedirectStandardError = $true
	$pinfo.RedirectStandardOutput = $true
	$pinfo.UseShellExecute = $false
	$pinfo.Arguments = $arg
	$pinfo.WorkingDirectory = $workingdir
	$pinfo.CreateNoWindow = $true
	$p = New-Object System.Diagnostics.Process
	$p.StartInfo = $pinfo
	$p.Start() | Out-Null
	if($wait)
	{
		$p.WaitForExit()
	}
	$stdout = $p.StandardOutput.ReadToEnd()
	$stderr = $p.StandardError.ReadToEnd()
	Write-Host $stdout
	if($stderr -ne $null)
	{
		Write-Host $stderr -ForegroundColor Red
	}
	Write-Host "stdout: $stdout"
	Write-Host "stderr: $stderr"
	#Write-Host "exit code: " + $p.ExitCode
}

<#
	Set-AzureProfile
	Set the azure profile under which the objects are to be created
#>
function Set-AzureProfile
{
    param(
    [string]$AzureProfilePath
    )
    
    #Save your azure profile. This is to avoid entering azure credentials everytime you run a powershell script
    #This is a json file in text format. If someone gets to this, you are done :)

	Try
	{
		   if([string]::IsNullOrEmpty($AzureProfilePath))
		{ 
			# Log in to your Azure account. Enable this for the first time to get the Azure Credential
			Login-AzureRmAccount | Out-Null
		}
		else
		{
			#get profile details from the saved json file
			#enable if you have a saved profile
			$profile = Select-AzureRmProfile -Path $AzureProfilePath
			#Set the Azure Context
			Set-AzureRmContext -SubscriptionId $profile.Context.Subscription.SubscriptionId 
		}
	}
	catch{
		$ErrorMessage = $_.Exception.Message
	    $FailedItem = $_.Exception.ItemName
		Write-host $ErrorMessage $FailedItem -ForegroundColor Red
	}


}
	

<#
	Create-AzureResourceGroup
	Create Azure Resource Group if it doesn't exits.
#>
function Create-AzureResourceGroup
{
    param(
    [string]$AzureProfilePath,
    [Parameter(Mandatory=$true)]
    [string]$resourcegroupname,
    [Parameter(Mandatory=$true)]
    [string]$location
    )

    #Configure the Azure Profile
	Try
	{
		#get current Azure context
		$context = Get-AzureRmContext -ErrorAction SilentlyContinue -ErrorVariable acerror
		#Set the context if not already set
		if($context -eq $null)
		{
			Set-AzureProfile -AzureProfilePath $AzureProfilePath
		}
		    
		$e = Get-AzureRmResourceGroup -Name $resourcegroupname -Location $location -ErrorAction SilentlyContinue -ErrorVariable rgerror
		if($e -ne $null)
		{
			Write-Host "Resource group $resourcegroupname exists at $location" -ForegroundColor Red;
			return;
		}

		if($rgerror -ne $null)
		{
			Write-host "Provisioning Azure Resource Group $resourcegroupname... " -ForegroundColor Green
			$b=New-AzureRmResourceGroup -Name $resourcegroupname -Location $location
			Write-host "$resourcegroupname provisioned." -ForegroundColor Green
		}
	
	}
    catch{
		$ErrorMessage = $_.Exception.Message
	    $FailedItem = $_.Exception.ItemName
		Write-host $ErrorMessage $FailedItem -ForegroundColor Red
	}

}


<#
	Create-AzureSQLServer
	Create Azure SQL Server if it doesn't exits.
#>
function Create-AzureSQLServer
{
    param(
        [string]$AzureProfilePath,
	    [Parameter(Mandatory=$true)]
        [string]$azuresqlservername,
	    [Parameter(Mandatory=$true)]
        [string]$resourcegroupname,
	    [Parameter(Mandatory=$true)]
        [string]$login,
	    [Parameter(Mandatory=$true)]
        [string]$password,
	    [Parameter(Mandatory=$true)]
        [string]$location
        )

	Try
	{
		#get current Azure context
		$context = Get-AzureRmContext -ErrorAction SilentlyContinue -ErrorVariable acerror
		#Set the context if not already set
		if($context -eq $null)
		{
			Set-AzureProfile -AzureProfilePath $AzureProfilePath
		}
    
		#create azure sql server if it doesn't exits
		$f = Get-AzureRmSqlServer -ServerName $azuresqlservername -ResourceGroupName $resourcegroupname -ErrorAction SilentlyContinue -ErrorVariable checkserver
    
		#Azure SQL Server already exists
		if($f -ne $null)
		{
			Write-Host "The Azure SQL Server $azuresqlservername exists in resource group $resourcegroupname" -ForegroundColor red 
			return;
		}

		#Azure SQL Server Doesn't exists.
		if ($checkserver -ne $null) 
		{ 
			#create a sql server
			Write-host "Provisioning Azure SQL Server $azuresqlservername ... " -ForegroundColor Green
			$c=New-AzureRmSqlServer -ResourceGroupName $resourcegroupname -ServerName $azuresqlservername -Location $location -SqlAdministratorCredentials $(New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $login, $(ConvertTo-SecureString -String $password -AsPlainText -Force))
			Write-host "$azuresqlservername provisioned." -ForegroundColor Green
		}

		#Set-AzureSQLServerFireWallRule -AzureProfilePath $AzureProfilePath -azuresqlservername $azuresqlservername -resourcegroupname $resourcegroupname -rulename "Home"
		
	}
	catch{
		$ErrorMessage = $_.Exception.Message
	    $FailedItem = $_.Exception.ItemName
		Write-host $ErrorMessage $FailedItem
	}

}


<#
	Set-AzureSQLServerFireWallRule
	Create FireWall Rule for Azure SQL Server
#>
function Set-AzureSQLServerFireWallRule
{
	 param(
        [Parameter(Mandatory=$false)]
        [string]$AzureProfilePath,
	    [Parameter(Mandatory=$true)]
        [string]$rulename,
	    [Parameter(Mandatory=$true)]
        [string]$azuresqlservername,
	    [Parameter(Mandatory=$true)]
        [string]$resourcegroupname,
	    [string]$startip,
        [string]$endip
        )
	
	Try
	{
		

        $d= Get-AzureRmSqlServerFirewallRule -FirewallRuleName $rulename -ServerName $azuresqlservername -ResourceGroupName $resourcegroupname -ErrorAction SilentlyContinue -ErrorVariable frerror
        
        if($d -ne $null)
        {
            Write-Host "Firewall Rule $rulename already exists for Server $azuresqlservername." -ForegroundColor Red
            return;
        }

        if($frerror -ne $null)
        {
            if($startip -eq "" -or $endip -eq "")
		    {
		        #get the public ip
		        $startip = (Invoke-WebRequest http://myexternalip.com/raw -UseBasicParsing).Content.trim();
		        $endip=$startip
		    }
	
		    Write-host "Creating firewall rule for $azuresqlservername ... " -ForegroundColor Green
	
		    #create the firewall rule
		    New-AzureRmSqlServerFirewallRule -ResourceGroupName $resourcegroupname  -ServerName $azuresqlservername -FirewallRuleName $rulename -StartIpAddress $startip -EndIpAddress $endip
        }
	}
	catch
	{
		$ErrorMessage = $_.Exception.Message
	    $FailedItem = $_.Exception.ItemName
		Write-host $ErrorMessage $FailedItem -ForegroundColor Red
	}

}

<#
	Create-AzureSQLDatabase
	Create Azure SQL Database
#>
function Create-AzureSQLDatabase
{
	param(
		[string]$AzureProfilePath,
		[Parameter(Mandatory=$true)]
		[string]$azuresqlservername,
		[Parameter(Mandatory=$true)]
		[string]$resourcegroupname,
		[Parameter(Mandatory=$true)]
		[string]$databasename,
		[Parameter(Mandatory=$true)]
		[string]$login,
		[Parameter(Mandatory=$true)]
		[string]$password,
		[Parameter(Mandatory=$true)]
		[string]$location,
		[Parameter(Mandatory=$false)]
		[string]$startip,
		[Parameter(Mandatory=$false)]
		[string]$endip,
		[Parameter(Mandatory=$false)]
		[string]$elasticpool=$null,
		[Parameter(Mandatory=$false)]
		[string]$pricingtier="S0"
	)
	
	Try
	{
		#get current Azure context
		$context = Get-AzureRmContext -ErrorAction SilentlyContinue -ErrorVariable acerror
		#Set the context if not already set
		if($context -eq $null)
		{
			Set-AzureProfile -AzureProfilePath $AzureProfilePath
		}

		#Create Azure Resource Group
		Create-AzureResourceGroup -AzureProfilePath $AzureProfilePath -resourcegroupname $resourcegroupname -location $location
	
		#Create Azure SQL Server
		Create-AzureSQLServer -AzureProfilePath $AzureProfilePath -azuresqlservername $azuresqlservername -resourcegroupname $resourcegroupname -login $login -password $password -location $location

		#Set Firewall rule
		Set-AzureSQLServerFireWallRule -AzureProfilePath $AzureProfilePath -azuresqlservername $azuresqlservername -resourcegroupname $resourcegroupname -startip $startip -endip $endip -rulename "Home"

		#check if Azure SQL Database Exists
		$d = Get-AzureRmSqlDatabase -DatabaseName $databasename -ServerName $azuresqlservername -ResourceGroupName $resourcegroupname -ErrorAction SilentlyContinue -ErrorVariable dberror

		if($d -ne $null)
		{
			Write-Host "Azure SQL Database $databasename already exists in Server $azuresqlservername..." -ForegroundColor Red
			return;
		}

		if($dberror -ne $null)
		{
			Write-Host "Provisioning $databasename..." -ForegroundColor Green
			if([string]::IsNullOrEmpty($elasticpool) -eq $true)
			{
				New-AzureRmSqlDatabase  -ResourceGroupName $resourcegroupname  -ServerName $azuresqlservername -DatabaseName $databasename -RequestedServiceObjectiveName $pricingtier
			}
			else
			{
				New-AzureRmSqlDatabase  -ResourceGroupName $resourcegroupname  -ServerName $azuresqlservername -DatabaseName $databasename -RequestedServiceObjectiveName $pricingtier -ElasticPoolName $elasticpool 
			}
	
		}

		Write-host "$databasename provisioned." -ForegroundColor Green
	}
	catch
	{
		$ErrorMessage = $_.Exception.Message
	    $FailedItem = $_.Exception.ItemName
		Write-host $ErrorMessage $FailedItem -ForegroundColor Red
	}

}


<#
	Delete-AzureSQLDatabase
	Delete Azure SQL Database
#>
function Delete-AzureSQLDatabase
{
	param(
		[string]$AzureProfilePath,
		[Parameter(Mandatory=$true)]
		[string]$azuresqlservername,
		[Parameter(Mandatory=$true)]
		[string]$resourcegroupname,
		[Parameter(Mandatory=$true)]
		[string]$databasename
	)

	Try
	{
		#get current Azure context
		$context = Get-AzureRmContext -ErrorAction SilentlyContinue -ErrorVariable acerror
		#Set the context if not already set
		if($context -eq $null)
		{
			Set-AzureProfile -AzureProfilePath $AzureProfilePath
		}

		$d = Get-AzureRmSqlDatabase -DatabaseName $databasename -ServerName $azuresqlservername -ResourceGroupName $resourcegroupname -ErrorAction SilentlyContinue -ErrorVariable dberror
		if($dberror -ne $null)
		{
			Write-Host "Azure SQL Database $databasename doesn't exists" -ForegroundColor Red
			return;
		}

		if($d -ne $null)
		{
			Write-Host "Deleting Azure SQL Database $databasename already exists in Server $azuresqlservername..." -ForegroundColor Green
			Remove-AzureRmSqlDatabase -DatabaseName $databasename -ServerName $azuresqlservername -ResourceGroupName $resourcegroupname
		}
		

	}
	catch
	{
		$ErrorMessage = $_.Exception.Message
	    $FailedItem = $_.Exception.ItemName
		Write-host $ErrorMessage $FailedItem -ForegroundColor Red
	}
}

<#
	Delete-AzureSQLServer
	Delete Azure SQL Server
#>
function Delete-AzureSQLServer
{
	param(
		[string]$AzureProfilePath,
		[Parameter(Mandatory=$true)]
		[string]$azuresqlservername,
		[Parameter(Mandatory=$true)]
		[string]$resourcegroupname
	)

	Try
	{
		#get current Azure context
		$context = Get-AzureRmContext -ErrorAction SilentlyContinue -ErrorVariable acerror
		#Set the context if not already set
		if($context -eq $null)
		{
			Set-AzureProfile -AzureProfilePath $AzureProfilePath
		}

		$f = Get-AzureRmSqlServer -ServerName $azuresqlservername -ResourceGroupName $resourcegroupname -ErrorAction SilentlyContinue -ErrorVariable checkserver
		
		#Azure SQL Server Doesn't exists.
		if ($checkserver -ne $null) 
		{ 
			Write-Host "Azure SQL Server $azuresqlservername doesn't exists." -ForegroundColor Green
			return;
		}
		
		#Azure SQL Server already exists
		if($f -ne $null)
		{
			Write-Host "Deleting Azure SQL Server $azuresqlservername" -ForegroundColor Green
			Remove-AzureRmSqlServer -ServerName $azuresqlservername -ResourceGroupName $resourcegroupname
			return;
		}

	}
	catch
	{
		$ErrorMessage = $_.Exception.Message
	    $FailedItem = $_.Exception.ItemName
		Write-host $ErrorMessage $FailedItem -ForegroundColor Red
	}
}

<#
	Delete-AzureSQLServerFirewallRule
	Delete Azure SQL Server Firewall Rule
#>
function Delete-AzureSQLServerFirewallRule
{
	param(
		[string]$AzureProfilePath,
		[Parameter(Mandatory=$true)]
		[string]$azuresqlservername,
		[Parameter(Mandatory=$true)]
		[string]$resourcegroupname,
		[Parameter(Mandatory=$true)]
		[string]$rulename
	)

	Try
	{

		#get current Azure context
		$context = Get-AzureRmContext -ErrorAction SilentlyContinue -ErrorVariable acerror
		#Set the context if not already set
		if($context -eq $null)
		{
			Set-AzureProfile -AzureProfilePath $AzureProfilePath
		}

        $d= Get-AzureRmSqlServerFirewallRule -FirewallRuleName $rulename -ServerName $azuresqlservername -ResourceGroupName $resourcegroupname -ErrorAction SilentlyContinue -ErrorVariable frerror
        
		if($frerror -ne $null)
        {
			Write-host "Azure SQL Server Firewall Rule $rulename doesn't exists." -ForegroundColor Green
			return;
		}
        if($d -ne $null)
        {
			Write-Host "Deleting Azure SQL Server Firewall Rule $rulename" -ForegroundColor Green
            Remove-AzureRmSqlServerFirewallRule -FirewallRuleName $rulename -ServerName $azuresqlservername -ResourceGroupName $resourcegroupname
        }

	}
	catch
	{
		$ErrorMessage = $_.Exception.Message
	    $FailedItem = $_.Exception.ItemName
		Write-host $ErrorMessage $FailedItem -ForegroundColor Red
	}
}


<#
	Delete-AzureResourceGroup
	Delete Azure Resource Group
#>
function Delete-AzureResourceGroup
{
	param(
		[string]$AzureProfilePath,
		[Parameter(Mandatory=$true)]
		[string]$resourcegroupname,
		[Parameter(Mandatory=$true)]
		[string]$location
	)

	Try
	{
		#get current Azure context
		$context = Get-AzureRmContext -ErrorAction SilentlyContinue -ErrorVariable acerror
		#Set the context if not already set
		if($context -eq $null)
		{
			Set-AzureProfile -AzureProfilePath $AzureProfilePath
		}
		    
		$e = Get-AzureRmResourceGroup -Name $resourcegroupname -Location $location -ErrorAction SilentlyContinue -ErrorVariable rgerror
		if($rgerror -ne $null)
		{
			Write-host "Azure Resource Group $resourcegroupname doesn't exists." -ForegroundColor Green
			return;
		}
		if($e -ne $null)
		{
			Write-Host "Deleting Azure Resource Group $resourcegroupname" -ForegroundColor Green
			Remove-AzureRmResourceGroup -Name $resourcegroupname
		}

	}
	catch
	{
		$ErrorMessage = $_.Exception.Message
	    $FailedItem = $_.Exception.ItemName
		Write-host $ErrorMessage $FailedItem -ForegroundColor Red
	}
}


<#
	Create-AzureStorageAccount
	Create Azure Storage Account
#>
function Create-AzureStorageAccount
{
	param(
		[Parameter(Mandatory=$true)]
		[string]$storageaccountname,
		[Parameter(Mandatory=$true)]
		[string]$resourcegroupname,
		[Parameter(Mandatory=$true)]
		[string]$location,
		[Parameter(Mandatory=$false)]
		[string]$skuname="Standard_LRS"

	)

	$sa = Get-AzureRmStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname -ErrorAction SilentlyContinue -ErrorVariable saerror
	if($sa -ne $null)
	{
		Write-Host "The storage account $storageaccountname already exists in resource group $resourcegroupname" -ForegroundColor red
		#Storage Account Exists. Do Nothing.
	}
	if($saerror -ne $null)
	{
		$sacname = Get-AzureRmStorageAccountNameAvailability -Name $storageaccountname
		if($sacname.NameAvailable -eq $false)
		{
			Write-Host $sacname.Message ": Please provide a different Azure Storage Account Name" -ForegroundColor Red
			Return;
		}
		Write-Host "Provisioning Storage Account $storageaccountname" -ForegroundColor Green
		#Storage Account Doesn't exists. Create a new one.
		$newsa = New-AzureRmStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname -SkuName $skuname -Location $location -ErrorAction SilentlyContinue -ErrorVariable newsaerror
		if($newsaerror -ne $null)
		{
			#error in creating storage account
			Write-Host $newsaerror -ForegroundColor Red
			return;
		}
		if($newsa -ne $null)
		{
			Write-Host $newsa;
		}
	}

}

<#
	Create-AzureStorageContainer
	Create Azure Storage Container
#>
function Create-AzureStorageContainer
{
	param(
		[Parameter(Mandatory=$true)]
		[string]$storageaccountname,
		[Parameter(Mandatory=$true)]
		[string]$resourcegroupname,
		[Parameter(Mandatory=$true)]
		[string]$containername,
		[Parameter(Mandatory=$false)]
		[string]$permission="Off"

	)
	
	#Set the current storage account
	Set-AzureRmCurrentStorageAccount -StorageAccountName $storageaccountname -ResourceGroupName $resourcegroupname

	$sac = New-AzureStorageContainer -Name $containername -Permission $permission -ErrorAction SilentlyContinue -ErrorVariable sacerror

	if($sac -ne $null)
	{
		Write-Host "Container $containername successfully created" -ForegroundColor Green
		
	}
	if($sacerror -ne $null)
	{
		Write-Host $sacerror -ForegroundColor Red
	}


}

<#
	Create-AzureStorageContainer
	Create Azure Storage Container
#>
function Delete-AzureStorageAccount
{
	param(
		[Parameter(Mandatory=$true)]
		[string]$storageaccountname,
		[Parameter(Mandatory=$true)]
		[string]$resourcegroupname
		
	)

	$sa = Get-AzureRmStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname -ErrorAction SilentlyContinue -ErrorVariable saerror
	if($saerror -ne $null)
	{
		Write-Host $saerror -ForegroundColor Red
	}

	if($sa -ne $null)
	{
		#Write-Host "The storage account $storageaccountname already exists in resource group $resourcegroupname" -ForegroundColor red
		#Storage Account Exists. Delete.
		$rma = Remove-AzureRmStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname -ErrorAction SilentlyContinue -ErrorVariable rmerror
		if($rma -ne $null)
		{
			Write-Host $rma -ForegroundColor Green
		}
		if($rmerror -ne $null)
		{
			Write-Host $rmerror
		}
	}

}

<#
	Delete-AzureStorageContainer
	Delete Azure Storage Container
#>
function Delete-AzureStorageContainer
{
	param(
		[Parameter(Mandatory=$true)]
		[string]$storageaccountname,
		[Parameter(Mandatory=$true)]
		[string]$resourcegroupname,
		[Parameter(Mandatory=$true)]
		[string]$containername

	)
	
	#Set the current storage account
	Set-AzureRmCurrentStorageAccount -StorageAccountName $storageaccountname -ResourceGroupName $resourcegroupname

	$sac = Remove-AzureStorageContainer -Name $containername -ErrorAction SilentlyContinue -ErrorVariable sacerror

	if($sac -ne $null)
	{
		Write-Host "$containername successfully deleted" -ForegroundColor Green
		
	}
	if($sacerror -ne $null)
	{
		Write-Host $sacerror -ForegroundColor Red
	}


}


<#
	UploadBlob-AzureStorageContainer
	Upload file to Azure Storage Container
#>
function UploadBlob-AzureStorageContainer
{
	param(
		[Parameter(Mandatory=$true)]
		[string]$storageaccountname,
		[Parameter(Mandatory=$true)]
		[string]$resourcegroupname,
		[Parameter(Mandatory=$true)]
		[string]$containername,
		[Parameter(Mandatory=$true)]
		[string]$file,
		[Parameter(Mandatory=$false)]
		[string]$directory,
		[Parameter(Mandatory=$false)]
		[string]$blobname

	)
	
	Try
	{
		#Set the current storage account
		Set-AzureRmCurrentStorageAccount -StorageAccountName $storageaccountname -ResourceGroupName $resourcegroupname

		#upload blob to Azure Storage Container
		if([string]::IsNullOrEmpty($file) -eq $false)
		{
			Set-AzureStorageBlobContent -File $file -Container $containername -Blob $blobname
		}
		if([string]::IsNullOrEmpty($directory) -eq $false)
		{
			ls –Recurse -Path $directory | Set-AzureStorageBlobContent -Container $containername -Force
		}
		
	}
	catch
	{
		$ErrorMessage = $_.Exception.Message
	    $FailedItem = $_.Exception.ItemName
		Write-host $ErrorMessage $FailedItem -ForegroundColor Red
	}	

}


<#
	Backup-AzureSQLDatabase
	Backup Azure SQL Database -bacpac,dacpac,csv export
	This can also backup on premise sql server
#>
Function Backup-AzureSQLDatabase
{
	param(
		[Parameter(Mandatory=$true)]
		[string]$type=$null, #bacpac,dacpac,CSV,export
		[Parameter(Mandatory=$false)]
		[string]$backupdirectory,
		[Parameter(Mandatory=$false)]
		[string]$sqlpackagepath,
		[Parameter(Mandatory=$true)]
		[string]$sqlserver,
		[Parameter(Mandatory=$true)]
		[string]$database,
		[Parameter(Mandatory=$true)]
		[string]$sqluser,
		[Parameter(Mandatory=$true)]
		[string]$sqlpassword,
		[Parameter(Mandatory=$false)]
		[string]$storageaccountname,
		[Parameter(Mandatory=$false)]
		[string]$resourcegroupname,
		[Parameter(Mandatory=$false)]
		[string]$container
		
	)

	if($sqlserver.Split('.').Count -le 1)
	{
		$sqlserver = "$sqlserver.database.windows.net"
	}

	if([string]::IsNullOrEmpty($type) -eq $true)
	{
		Write-Host "Enter a valid backup type(bacpac/dacpac/csv)" -ForegroundColor Red
		return;
	}

	if($type -eq "bacpac")
	{
		Write-Host "Creating bacpac file at $backupdirectory" -ForegroundColor Green
		$backuppath = $backupdirectory + "/" + "$database.bacpac"
		$action = "Export"
		$arg = "/Action:Export /ssn:$sqlserver /sdn:$database /su:$sqluser /sp:$sqlpassword /tf:$backuppath"
		fn_executeprocess -filename $sqlpackagepath -arg $arg
	}

	if($type -eq "dacpac")
	{
		Write-Host "Creating dacpac file at $backupdirectory" -ForegroundColor Green
		$backuppath = $backupdirectory + "/" + "$database.dacpac"
		#$log = $backupdirectory + "/" + "$database.log"
		$arg = "/Action:Extract /ssn:$sqlserver /sdn:$database /su:$sqluser /sp:$sqlpassword /tf:$backuppath"
		fn_executeprocess -filename $sqlpackagepath -arg $arg
		
	}


	if($type -eq "csv")
	{
		# include smo assembly
		[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | out-null

		# Create the data directory
		$datadirectory = $backupdirectory + "\data"
		New-Item -ItemType Directory -Force -Path $datadirectory

		$azuresqluser = $sqluser + "@" + $sqlserver.Split('.')[0]
		# connect to Azure SQL Database
		$cn = "Server=$sqlserver;Database=$database;User ID=$azuresqluser;Password=$sqlpassword"
		$conn = New-Object System.Data.SqlClient.SqlConnection
		$conn.ConnectionString = $cn

		# smo server object
		$azsrv = New-Object ("Microsoft.SqlServer.Management.Smo.Server") $conn
		# smo database object
		$azdb = $azsrv.Databases[$database]

		# execute the query to get all user tables and save results in a data source object
		$dataset=$azdb.ExecuteWithResults("select ss.name + '.' + st.name from sys.tables st join sys.schemas ss on st.schema_id=ss.schema_id");

		#bcp out each table in $dataset
		Foreach ($table in $dataset.Tables)
		{
			# loop through each row in a table
			Foreach ($row in $table.Rows)
			{
				# loop through every column in a table
				Foreach ($col in $table.Columns)
				{
					$outtable = $database + "." + $row.Item($col)
					$outfile = $datadirectory + $row.Item($col) + ".dat"
    
					# export source table data to .dat file
					Write-Host "Bcp out $outtable in $outfile"
					bcp $outtable out "$outfile" -U $azuresqluser -P $sqlpassword -S tcp:$sqlserver -E -n -C RAW
					
                }
			}
		} 

	}

	if($type -eq "export")
	{
		
		if([string]::IsNullOrEmpty($storageaccountname) -eq $true)
		{
			Write-Host "Provide a valid Storage Account Name" -ForegroundColor Red
			return
		}
		if([string]::IsNullOrEmpty($resourcegroupname) -eq $true)
		{
			Write-Host "Provide a valid resource group" -ForegroundColor Red
			return
		}
		if([string]::IsNullOrEmpty($container) -eq $true)
		{
			Write-Host "Provide a valid Storage Container Name" -ForegroundColor Red
			return
		}
		
		# add timestamp to the bacpac file
		$bacpacFilename = $DatabaseName + (Get-Date).ToString("ddMMyyyymm") + ".bacpac"

		# set the current storage account
		$storageaccountkey = Get-AzureRmStorageAccountKey -ResourceGroupName $resourcegroupname -Name $storageaccountname
		
		# set the bacpac location
		$bloblocation = "https://$storageaccountname.blob.core.windows.net/$container/$bacpacFilename"
		Set-AzureRmCurrentStorageAccount -StorageAccountName $storageaccountname -ResourceGroupName $resourcegroupname
		#set the credential
		$securesqlpassword = ConvertTo-SecureString -String $sqlpassword -AsPlainText -Force
		$credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $sqluser, $securesqlpassword

		Write-Host "Exporting $database to $bloblocation..." -ForegroundColor Green
		$export = New-AzureRmSqlDatabaseExport -ResourceGroupName $resourcegroupname -ServerName $sqlserver.Split('.')[0] `
		-DatabaseName $database -StorageUri $bloblocation -AdministratorLogin $credentials.UserName `
		-AdministratorLoginPassword $credentials.Password -StorageKeyType StorageAccessKey -StorageKey $storageaccountkey.Value[0].Tostring()

		Write-Host $export -ForegroundColor Green

		# Check status of the export
		While(1 -eq 1)
		{
			$exportstatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $export.OperationStatusLink
			if($exportstatus.Status -eq "Succeeded")
			{
				Write-Host $exportstatus.StatusMessage -ForegroundColor Green
				return
			}
			If($exportstatus.Status -eq "InProgress")
			{
				Write-Host $exportstatus.StatusMessage -ForegroundColor Green
				Start-Sleep -Seconds 5
			}
		}
		
	}	

}


<#
Function Restore-AzureSQLDatabase
restore azure sql database from bacpac,dacpac,csv, import bacpac from storage account or point in time
#>
Function Restore-AzureSQLDatabase
{
	param(
		[Parameter(Mandatory=$true)]
		[string]$type=$null, #bacpac,dacpac,import,csv,pointintime
		[Parameter(Mandatory=$false)]
		[string]$backupfile,
		[Parameter(Mandatory=$false)]
		[string]$sqlpackagepath,
		[Parameter(Mandatory=$true)]
		[string]$sqlserver,
		[Parameter(Mandatory=$true)]
		[string]$database,
		[Parameter(Mandatory=$true)]
		[string]$sqluser,
		[Parameter(Mandatory=$true)]
		[string]$sqlpassword,
		[Parameter(Mandatory=$false)]
		[string]$storageaccountname,
		[Parameter(Mandatory=$false)]
		[string]$resourcegroupname,
		[Parameter(Mandatory=$false)]
		[string]$container,
		[Parameter(Mandatory=$false)]
		[string]$replace=$false,
		[Parameter(Mandatory=$false)]
		[string]$serviceobjectivename="P6",
		[Parameter(Mandatory=$false)] 
		[string]$edition="Standard",
		[Parameter(Mandatory=$false)] 
		[string]$dbmaxsizebytes=1000000000,
		[Parameter(Mandatory=$false)] 
		[string]$newdatabasename							
	)

	$sqlservershortname = $sqlserver.Split('.')[0];
	$sqlserverlongname = "$sqlservershortname.database.windows.net"
	

	#Import bacpac from local system
	if([string]::IsNullOrEmpty($type) -eq $true)
	{
		Write-Host "Enter a valid backup type(bacpac/dacpac/csv)" -ForegroundColor Red
		return;
	}
	
	$newdatabasename = $database + (Get-Date).ToString("MMddyyyymm")
	if($replace -eq $true -and $type -ne "pointintime")
	{
		#rename the existing database
		# add the azure account again as the rename cmdlet doens't works in Resource Manager version
		Add-AzureAccount

		#rename the database 
		
		Write-Host "Renaming $database to $dboldname"
		Set-AzureSqlDatabase -ServerName $sqlservershortname -DatabaseName $database -NewDatabaseName $dboldname
		$newdatabasename = $database

	}

	if($type -eq "bacpac")
	{
		$sqlserverlongname
		#Write-Host "Creating bacpac file at $backupdirectory" -ForegroundColor Green
		#$backuppath = $backupdirectory + "/" + "$database.bacpac"
		#$action = "Export"
		$arg = "/Action:Import /tsn:$sqlserverlongname /tdn:$newdatabasename /tu:$sqluser /tp:$sqlpassword /sf:$backupfile"
		$arg
		fn_executeprocess -filename $sqlpackagepath -arg $arg
	}

	if($type -eq "dacpac")
	{
		Write-Host "Importing database $database from $backupfile" -ForegroundColor Green
		$sqlserver
		$arg = "/a:publish /sf:$backupfile /tsn:$sqlserverlongname /tdn:$newdatabasename /tu:$sqluser /tp:$sqlpassword"
		fn_executeprocess -filename $sqlpackagepath -arg $arg
	}

	if($type -eq "import")
	{
		# set the current storage account
		$storageaccountkey = Get-AzureRmStorageAccountKey -ResourceGroupName $resourcegroupname -Name $storageaccountname
		
		# set the bacpac location	
		$bloblocation = "https://$storageaccountname.blob.core.windows.net/$container/$backupfile"
		Set-AzureRmCurrentStorageAccount -StorageAccountName $storageaccountname -ResourceGroupName $resourcegroupname
		#set the credential
		$securesqlpassword = ConvertTo-SecureString -String $sqlpassword -AsPlainText -Force
		$credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $sqluser, $securesqlpassword

		Write-Host "Importing $database from $bloblocation..." -ForegroundColor Green
		
		#$import = New-AzureRmSqlDatabaseImport -ResourceGroupName $resourcegroupname -ServerName $sqlserver.Split('.')[0] `
		#-DatabaseName $database -StorageUri $bloblocation -AdministratorLogin $credentials.UserName `
		#-AdministratorLoginPassword $credentials.Password -StorageKeyType StorageAccessKey -StorageKey $storageaccountkey.Value[0].Tostring()
		$import =  New-AzureRmSqlDatabaseImport -DatabaseName $newdatabasename -ServerName $sqlservershortname -StorageKeyType StorageAccessKey -StorageKey $storageaccountkey.Value[0].Tostring() `
		-StorageUri $bloblocation -AdministratorLogin $credentials.UserName -AdministratorLoginPassword `
		$credentials.Password -ResourceGroupName $resourcegroupname -Edition $edition -ServiceObjectiveName $serviceobjectivename -DatabaseMaxSizeBytes $dbmaxsizebytes

		# Check status of the export
		While(1 -eq 1)
		{
			$importstatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $import.OperationStatusLink
			if($importstatus.Status -eq "Succeeded")
			{
				Write-Host $importstatus.StatusMessage -ForegroundColor Green
				return
			}
			If($importstatus.Status -eq "InProgress")
			{
				Write-Host $importstatus.StatusMessage -ForegroundColor Green

				Start-Sleep -Seconds 10
			}
		}
	}

	if($type -eq "pointintime")
	{
		While (1)
		{
			$restoredetails = Get-AzureRmSqlDatabaseRestorePoints -ServerName $sqlservershortname -DatabaseName $database -ResourceGroupName $resourcegroupname
			$erd=$restoredetails.EarliestRestoreDate.ToString();
			$restoretime = Read-Host "The earliest restore time is $erd.`n Enter a restore time between Earlist restore time and current time." 
			$restoretime = $restoretime -as [DateTime]
			if(!$restoretime)
			{
				Write-Host "Enter a valid date" -ForegroundColor Red
			}else
			{
				break;
			}
		}

		$db = Get-AzureRmSqlDatabase -DatabaseName $database -ServerName $sqlservershortname -ResourceGroupName $resourcegroupname
		
		Write-Host "Restoring Database $database as of $restoretime"

		$restore = Restore-AzureRmSqlDatabase -FromPointInTimeBackup -PointInTime $restoretime -ResourceId $db.ResourceId -ServerName `
		$db.ServerName -TargetDatabaseName $newdatabasename -Edition $db.Edition -ServiceObjectiveName $db.CurrentServiceObjectiveName `
		-ResourceGroupName $db.ResourceGroupName -ErrorAction SilentlyContinue -ErrorVariable rerror
		
		if($rerror -ne $null)
		{
			Write-Host $rerror -ForegroundColor red;
		}
		if($restore -ne $null)
		{
			Write-Host "Database $newdatabasename restored Successfully";
		}

		if($replace -eq $true)
		{
			Add-AzureAccount
			$tempdbname = $database + "old"
			#switch the database name
			Write-Host "Renaming databases...." 
			Set-AzureSqlDatabase -ServerName $sqlservershortname -DatabaseName $database -NewDatabaseName $tempdbname
			Set-AzureSqlDatabase -ServerName $sqlservershortname -DatabaseName $newdatabasename -NewDatabaseName $database
			#Delete-AzureSQLDatabase -azuresqlservername $sqlservershortname -resourcegroupname $resourcegroupname -databasename $tempdbname
		}

	}
	
}

