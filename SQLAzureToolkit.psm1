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
Save Azure Profile information into a json file 
#>
function Save-AzureProfile
{
	param(
		[Parameter(Mandatory=$true)]
		[string]$AzureProfilePath
	)
	Write-Host "Login to your Azure Account" -ForegroundColor Green
	Login-AzAccount | Save-AzProfile -Path $AzureProfilePath -Force -ErrorVariable errorvar
	if(!$errorvar)
	{
		Write-Host "Azure Profile details saved in $AzureProfilePath. You can now use it to login to Azure PowerShell." -ForegroundColor Green

	}


}
<#
	Set-AzureProfile
	Set the azure profile under which the objects are to be created
#>
function Set-AzureProfile
{
    param(
	[AllowEmptyString()]
    [string]$AzureProfilePath
    )
    
    Try
	{
		#Login to Azure Account
		if(![string]::IsNullOrEmpty($AzureProfilePath))
		{
			#If Azure profile file is available get the profile information from the file
		    $profile = Import-AzContext -Path $AzureProfilePath
			#retrieve the subscription id from the profile.
		    $SubscriptionID = $profile.Context.Subscription.SubscriptionId
		}
		else
		{
		    Write-Host "File Not Found $AzureProfilePath" -ForegroundColor Red
			
			# If the Azure Profile file isn't available, login using the dialog box.
		    # Provide your Azure Credentials in the login dialog box
		    $profile = Login-AzAccount
		    $SubscriptionID =  $profile.Context.Subscription.SubscriptionId
		}

		#Set the Azure Context
		Set-AzureRmContext -SubscriptionId $SubscriptionID | Out-Null
		Write-Host "SubscriptionId: $SubscriptionID"
	}
	catch{
		$ErrorMessage = $_.Exception.Message
	    $FailedItem = $_.Exception.ItemName
		Write-host $ErrorMessage $FailedItem -ForegroundColor Red
	}


}
	

<#
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

    #Configure Azure Profile
	Try
	{
		Set-AzureProfile -AzureProfilePath $AzureProfilePath

		$e = Get-AzureRmResourceGroup -Name $resourcegroupname -Location $location -ErrorAction SilentlyContinue -ErrorVariable rgerror
		if($e -ne $null)
		{
			Write-Host "Resource group $resourcegroupname exists at $location" -ForegroundColor Red;
			return;
		}

		if($rgerror -ne $null)
		{
			Write-host "Provisioning Azure Resource Group $resourcegroupname... " -ForegroundColor Green
			New-AzureRmResourceGroup -Name $resourcegroupname -Location $location -ErrorAction Stop
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
		Set-AzureProfile -AzureProfilePath $AzureProfilePath
    
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
			New-AzureRmSqlServer -ResourceGroupName $resourcegroupname -ServerName $azuresqlservername -Location $location -SqlAdministratorCredentials $(New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $login, $(ConvertTo-SecureString -String $password -AsPlainText -Force) -ErrorAction Stop)
			<#
			if(!$errorvar)
			{
				Write-host "$azuresqlservername provisioned." -ForegroundColor Green
			}
			#>
		}
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
		Set-AzureProfile -AzureProfilePath $AzureProfilePath

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
		Set-AzureProfile -AzureProfilePath $AzureProfilePath

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
				New-AzureRmSqlDatabase  -ResourceGroupName $resourcegroupname  -ServerName $azuresqlservername -DatabaseName $databasename -RequestedServiceObjectiveName $pricingtier -ErrorAction Stop
			}
			else
			{
				New-AzureRmSqlDatabase  -ResourceGroupName $resourcegroupname  -ServerName $azuresqlservername -DatabaseName $databasename -RequestedServiceObjectiveName $pricingtier -ElasticPoolName $elasticpool -ErrorAction Stop
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
		Set-AzureProfile -AzureProfilePath $AzureProfilePath

		$d = Get-AzureRmSqlDatabase -DatabaseName $databasename -ServerName $azuresqlservername -ResourceGroupName $resourcegroupname -ErrorAction SilentlyContinue -ErrorVariable dberror
		if($dberror -ne $null)
		{
			Write-Host "Azure SQL Database $databasename doesn't exists" -ForegroundColor Red
			return;
		}

		if($d -ne $null)
		{
			Write-Host "Deleting Azure SQL Database $databasename already exists in Server $azuresqlservername..." -ForegroundColor Green
			Remove-AzureRmSqlDatabase -DatabaseName $databasename -ServerName $azuresqlservername -ResourceGroupName $resourcegroupname -ErrorAction Stop
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
		Set-AzureProfile -AzureProfilePath $AzureProfilePath

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
			Remove-AzureRmSqlServer -ServerName $azuresqlservername -ResourceGroupName $resourcegroupname -ErrorAction Stop
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

		Set-AzureProfile -AzureProfilePath $AzureProfilePath

        $d= Get-AzureRmSqlServerFirewallRule -FirewallRuleName $rulename -ServerName $azuresqlservername -ResourceGroupName $resourcegroupname -ErrorAction SilentlyContinue -ErrorVariable frerror
        
		if($frerror -ne $null)
        {
			Write-host "Azure SQL Server Firewall Rule $rulename doesn't exists." -ForegroundColor Green
			return;
		}
        if($d -ne $null)
        {
			Write-Host "Deleting Azure SQL Server Firewall Rule $rulename" -ForegroundColor Green
            Remove-AzureRmSqlServerFirewallRule -FirewallRuleName $rulename -ServerName $azuresqlservername -ResourceGroupName $resourcegroupname -ErrorAction Stop
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
		Set-AzureProfile -AzureProfilePath $AzureProfilePath
		    
		$e = Get-AzureRmResourceGroup -Name $resourcegroupname -Location $location -ErrorAction SilentlyContinue -ErrorVariable rgerror
		if($rgerror -ne $null)
		{
			Write-host "Azure Resource Group $resourcegroupname doesn't exists." -ForegroundColor Green
			return;
		}
		if($e -ne $null)
		{
			Write-Host "Deleting Azure Resource Group $resourcegroupname" -ForegroundColor Green
			Remove-AzureRmResourceGroup -Name $resourcegroupname -ErrorAction Stop
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
		[string]$skuname="Standard_LRS",
		[Parameter(Mandatory=$false)]
		[string]$AzureProfilePath

	)

	Set-AzureProfile -AzureProfilePath $AzureProfilePath

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
		[string]$permission="Off",
		[Parameter(Mandatory=$false)]
		[string]$AzureProfilePath

	)
	
	Set-AzureProfile -AzureProfilePath $AzureProfilePath

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
		[string]$resourcegroupname,
		[Parameter(Mandatory=$false)]
		[string]$AzureProfilePath
		
	)

	Set-AzureProfile -AzureProfilePath $AzureProfilePath

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
		[string]$containername,
		[Parameter(Mandatory=$false)]
		[string]$AzureProfilePath

	)
	
	Set-AzureProfile -AzureProfilePath $AzureProfilePath

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
		Set-AzureProfile -AzureProfilePath $AzureProfilePath

		#Set the current storage account
		Set-AzureRmCurrentStorageAccount -StorageAccountName $storageaccountname -ResourceGroupName $resourcegroupname -ErrorAction Stop

		#upload blob to Azure Storage Container
		if([string]::IsNullOrEmpty($file) -eq $false)
		{
			Set-AzureStorageBlobContent -File $file -Container $containername -Blob $blobname -ErrorAction Stop
		}
		if([string]::IsNullOrEmpty($directory) -eq $false)
		{
			ls �Recurse -Path $directory | Set-AzureStorageBlobContent -Container $containername -Force
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
		[string]$container,
		[Parameter(Mandatory=$false)]
		[string]$AzureProfilePath
		
	)

	Set-AzureProfile -AzureProfilePath $AzureProfilePath

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
		Set-AzureRmCurrentStorageAccount -StorageAccountName $storageaccountname -ResourceGroupName $resourcegroupname -ErrorAction Stop
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
	
	Set-AzureProfile -AzureProfilePath $AzureProfilePath

	#Import bacpac from local system
	if([string]::IsNullOrEmpty($type) -eq $true)
	{
		Write-Host "Enter a valid backup type(bacpac/dacpac/csv)" -ForegroundColor Red
		return;
	}
	
	#set the new database name
	$newdatabasename = $database + (Get-Date).ToString("MMddyyyymm")
	
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

		
	}

	if($type -eq "deleted")
	{
		
		$deleteddb = Get-AzureRmSqlDeletedDatabaseBackup -ServerName $sqlservershortname -DatabaseName $database -ResourceGroupName $resourcegroupname
		$deletedatabasename = $deleteddb.DatabaseName.ToString()
		Write-Host "Restoring database $deletedatabasename from Deleted Database" -ForegroundColor Green
		$restore=Restore-AzureRmSqlDatabase -FromDeletedDatabaseBackup -DeletionDate $deleteddb.DeletionDate -ResourceId $deleteddb.ResourceID `
		-ServerName $sqlservershortname -TargetDatabaseName $newdatabasename -Edition $deleteddb.Edition -ServiceObjectiveName $deleteddb.ServiceLevelObjective `
		-ResourceGroupName $resourcegroupname 
		
		$restoredb = $restore.DatabaseName.ToString()
		Write-Host "Database $database restored from deleted databases as database $restoredb" -ForegroundColor Green
		#Write-Host $restoredeleted.ToString() -ForegroundColor Green
		
	}

	if($type -eq "geo")
	{
		
		$geodb = Get-AzureRmSqlDatabaseGeoBackup -ServerName $sqlservershortname -DatabaseName $database -ResourceGroupName $resourcegroupname
		$geodtabasename = $geodb.DatabaseName.ToString()
		
		Write-Host "Restoring database $geodtabasename from geo backup" -ForegroundColor Green
		 
		$restore = Restore-AzureRmSqlDatabase -FromGeoBackup -ResourceId $geodb.ResourceID -ServerName $sqlservershortname -TargetDatabaseName $newdatabasename `
		-Edition $geodb.Edition -ResourceGroupName $resourcegroupname -ServiceObjectiveName $serviceobjectivename

		$restoredb = $restore.DatabaseName.ToString()
		Write-Host "Database $database restored from Geo Backup as database $restoredb" -ForegroundColor Green

		
	}
	
	if($replace -eq $true)
	{
		Swap-AzureSQLDatabase -sqlservername $sqlservershortname -databasename $database -newdatabasename $newdatabasename -rgn $resourcegroupname
	}
}

function Swap-AzureSQLDatabase
{
	param(
		[string]$sqlservername,
		[string]$databasename,
		[string]$newdatabasename,
		[string]$rgn
)

	Set-AzureProfile -AzureProfilePath $AzureProfilePath
	$tempdbname = $database + "old" + (Get-Date).ToString("MMddyyyymmss")

	$d = Get-AzureRmSqlDatabase -DatabaseName $databasename -ServerName $sqlservername -ResourceGroupName $rgn -ErrorAction SilentlyContinue -ErrorVariable dberror
	Write-Host $d
	Write-Host $dberror
	
	if($d -eq $null)
	{
		#Original database doesn't exists. Just rename the new database to original database.
		Write-Host "Renaming database $newdatabasename to $databasename" -ForegroundColor Green
	
		Set-AzureRmSqlDatabase -ServerName $sqlservername -DatabaseName $newdatabasename -NewName $databasename
	}
	else
	{
		#original database exists. Swap the names
		Write-Host "Renaming database $databasename to $tempdbname" -ForegroundColor Green
		Set-AzureRmSqlDatabase -ServerName $sqlservername -DatabaseName $databasename -NewName $tempdbname 

		Start-Sleep -s 60

		Write-Host "Renaming database $newdatabasename to $databasename" -ForegroundColor Green
		Set-AzureSqlDatabase -ServerName $sqlservername -DatabaseName $newdatabasename -NewDatabaseName $databasename
	}
	
}

function Rename-AzureSqlDatabase
{
	param (
		[parameter(Mandatory=$True)]
		[string]$ServerName,
		[parameter(Mandatory=$True)]
		[string]$ResourceGroupName,
		[parameter(Mandatory=$True)]
		[string]$DatabaseName,
		[parameter(Mandatory=$True)]
		[string]$NewDatabaseName,
		[string]$AzureProfilePath
	)

	Set-AzureProfile -AzureProfilePath $AzureProfilePath

	$d = Get-AzureRmSqlDatabase -DatabaseName $databasename -ServerName $ServerName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue -ErrorVariable dberror
	
	if($d -ne $null)
	{
		Write-Host "Renaming database $DatabaseName to $NewDatabaseName..." -ForegroundColor Green
	
		Set-AzureRmSqlDatabase -ServerName $ServerName -DatabaseName $DatabaseName -NewName $NewDatabaseName -ResourceGroupName $ResourceGroupName
	}else
	{
		Write-Host $dberror
	}
	
}


function Manage-AzureSQLDBGeoReplication
{
	param(
		[parameter(Mandatory=$true)]
		[string]$Operation,
		[parameter(Mandatory=$true)]
		[string]$ResourceGroupName,
		[parameter(Mandatory=$true)]
		[string]$PrimarySQLServer,
		[parameter(Mandatory=$true)]
		[string]$SecondarySQLServer,
		[parameter(Mandatory=$true)]
		[string]$Sqladminuser,
		[parameter(Mandatory=$true)]
		[string]$Sqladminpassword,
		[parameter(Mandatory=$true)]
		[string]$SecondaryServerLocation,
		[parameter(Mandatory=$true)]
		[string]$Databases, # Comma delimited list of databases to replicate
		[AllowEmptyString()]
		[string]$AzureProfilePath

	)

	Set-AzureProfile -AzureProfilePath $AzureProfilePath;
	try
	{
	switch($Operation)
	{
		#Enable Active Geo Replication
		Enable 
		{
			#verify if primary sql server exists, if not terminate
			Get-AzureRmSqlServer -ResourceGroupName $ResourceGroupName -ServerName $PrimarySQLServer -ErrorAction Stop

			# verify if secondary sql server exists, if not create
			Write-Host "Provisioning SQL Server $SecondarySQLServer..."
			Create-AzureSQLServer -azuresqlservername $SecondarySQLServer -resourcegroupname $ResourceGroupName `
					-login $Sqladminuser -password $Sqladminpassword -location $SecondaryServerLocation;

			

			# Exit if no databases are available for replication
			if([string]::IsNullOrEmpty($Databases))
			{
				Write-Host "No database to replicate" -ForegroundColor Green
				break;
			}

			# Replicate individual databases
			$Databases.Split(',') | ForEach-Object {
				Write-Host "Replicating database $_ from $PrimarySQLServer to $SecondarySQLServer..." -ForegroundColor Green
				$db = Get-AzureRmSqlDatabase -DatabaseName $_ -ResourceGroupName $ResourceGroupName -ServerName $PrimarySQLServer -ErrorAction SilentlyContinue -ErrorVariable dberror
				# break if database doesn't exists
				if($dberror)
				{
					Write-Host $dberror -ForegroundColor Red
					
				}

				$db | New-AzureRmSqlDatabaseSecondary -PartnerResourceGroupName $ResourceGroupName -PartnerServerName $SecondarySqlServer -AllowConnections "No"  -ErrorAction Stop
				
			}

		}

		# Manual failover to secondary
		Failover
		{

			# failover individual databases
			$Databases.Split(',') | ForEach-Object {
				Write-Host "Failover database $_ from $PrimarySQLServer to $SecondarySQLServer..." -ForegroundColor Green
				$db = Get-AzureRmSqlDatabase -DatabaseName $_ -ResourceGroupName $ResourceGroupName -ServerName $SecondarySQLServer -ErrorAction SilentlyContinue -ErrorVariable dberror
				# break if database doesn't exists
				if($dberror)
				{
					Write-Host $dberror -ForegroundColor Red
					
				}

				$db | Set-AzureRmSqlDatabaseSecondary -PartnerResourceGroupName $ResourceGroupName -Failover -ErrorAction Stop 
				
			}
		}

		Disable {
			# remove individual databases from replication
			
			$Databases.Split(',') | ForEach-Object {
				Write-Host "Remove replication for database $_ ..." -ForegroundColor Green
				
				$db = Get-AzureRmSqlDatabase -DatabaseName $_ -ResourceGroupName $ResourceGroupName -ServerName $PrimarySQLServer -ErrorAction SilentlyContinue -ErrorVariable dberror
				# break if database doesn't exists
				if($dberror)
				{
					Write-Host $dberror -ForegroundColor Red
					
				}

				$db | Remove-AzureRmSqlDatabaseSecondary -PartnerResourceGroupName $ResourceGroupName -ServerName $PrimarySqlServer -PartnerServerName $SecondarySqlServer -ErrorAction Stop
				Write-Host "Disabling replication doesn't removes secondary server and databases. You can remove them using Delete-AzureSqlServer and Delete-AzureSqlDatabase cmdlets";
			}
		}
	}
		}catch
	{
		Write-host $_ -ForegroundColor Red
	}



}

function Manage-FailoverGroup
{
	param(
		[parameter(Mandatory=$true)]
		[string]$Operation,
		[parameter(Mandatory=$true)]
		[string]$ResourceGroupName,
		[parameter(Mandatory=$true)]
		[string]$PrimarySQLServer,
		[parameter(Mandatory=$true)]
		[string]$SecondarySQLServer,
		[parameter(Mandatory=$true)]
		[string]$Sqladminuser,
		[parameter(Mandatory=$true)]
		[string]$Sqladminpassword,
		[parameter(Mandatory=$true)]
		[string]$SecondaryServerLocation,
		[parameter(Mandatory=$true)]
		[string]$FailoverGroupName,
		[parameter(Mandatory=$false)]
		[int]$GracePeriodWithDataLossHours=1,
		[parameter(Mandatory=$true)]
		[string]$Databases, # Comma delimited list of databases to replicate
		[AllowEmptyString()]
		[string]$AzureProfilePath
	)
	
	Set-AzureProfile -AzureProfilePath $AzureProfilePath;
	
	#verify if primary sql server exists, if not terminate
	Get-AzureRmSqlServer -ResourceGroupName $ResourceGroupName -ServerName $PrimarySQLServer -ErrorAction Stop
	try
	{
		Switch($Operation)
		{
			Enable
			{

			#Create Secondary Server if it doesn't exists
			Create-AzureSQLServer -AzureProfilePath $AzureProfilePath `
			-azuresqlservername $SecondarySQLServer `
			-resourcegroupname $ResourceGroupName `
			-login $Sqladminuser `
			-password $Sqladminpassword `
			-location $SecondaryServerLocation

			#Create failover group
			Write-Host "Creating the failover group $FailoverGroupName " -ForegroundColor Green
			$failovergroup = New-AzureRMSqlDatabaseFailoverGroup -ResourceGroupName $ResourceGroupName `
			-ServerName $PrimarySQLServer `
			-PartnerServerName $SecondarySQLServer `
			-FailoverGroupName $FailoverGroupName `
			-FailoverPolicy Automatic `
			-GracePeriodWithDataLossHours 1 `
			-ErrorAction stop
			#Add databases to the failover group
			# Replicate individual databases
			$Databases.Split(',') | ForEach-Object {
				Write-Host "Adding database $_ from to failover group $FailoverGroupName..." -ForegroundColor Green
				$db = Get-AzureRmSqlDatabase -DatabaseName $_ -ResourceGroupName $ResourceGroupName -ServerName $PrimarySQLServer -ErrorAction SilentlyContinue -ErrorVariable dberror
				# break if database doesn't exists
				if($dberror)
				{
					Write-Host $dberror -ForegroundColor Red
					
				}

				$db | Add-AzureRmSqlDatabaseToFailoverGroup -ServerName $PrimarySQLServer -FailoverGroupName $FailoverGroupName -ResourceGroupName $ResourceGroupName  -ErrorAction stop
								
			}
		}
			Failover
			{
				#Failover the failover group to the secondary server.
				#Failover group can do an automatic failover. 
				Write-Host "Failing over to the secondary server..."
				Switch-AzureRMSqlDatabaseFailoverGroup -ResourceGroupName $ResourceGroupName -ServerName $SecondarySQLServer -FailoverGroupName $FailoverGroupName -ErrorAction stop
			}

			Disable
			{
				#Remove individual databases from the failover group
				$Databases.Split(',') | ForEach-Object {
				Write-Host "Removing database $_ from the failover group $FailoverGroupName..." -ForegroundColor Green
				
				$db = Get-AzureRmSqlDatabase -DatabaseName $_ -ResourceGroupName $ResourceGroupName -ServerName $PrimarySQLServer -ErrorAction SilentlyContinue -ErrorVariable dberror
				# break if database doesn't exists
				if($dberror)
				{
					Write-Host $dberror -ForegroundColor Red
					
				}
				#Remove database from the failover group
				$db | Remove-AzureRmSqlDatabaseFailoverGroup -ServerName $PrimarySQLServer -FailoverGroupName $FailoverGroupName -ErrorAction Stop
				#Remove the replicatin link
				$db | Remove-AzureRmSqlDatabaseSecondary -PartnerResourceGroupName $ResourceGroupName -ServerName $PrimarySqlServer -PartnerServerName $SecondarySqlServer -ErrorAction Stop
				Write-Host "Disabling replication doesn't removes secondary server and databases. You can remove them using Delete-AzureSqlServer and Delete-AzureSqlDatabase cmdlets";

				#delete the failover group
			}
			
			}
			Remove
			{
				#delete failovergroup.
				Remove-AzureRmSqlDatabaseFailoverGroup -ServerName $PrimarySQLServer -FailoverGroupName $FailoverGroupName -ResourceGroupName $ResourceGroupName -ErrorAction Stop
			}
		}
		
	}
	catch
	{
		$ErrorMessage = $_.Exception.Message
	    $FailedItem = $_.Exception.ItemName
		Write-host $ErrorMessage $FailedItem -ForegroundColor Red
	}

	
		
	
}

function Modify-AzureSqlDatabase
{
	param(
		
		[parameter(Mandatory=$True)]
		[string]$ServerName,
		[parameter(Mandatory=$True)]
		[string]$ResourceGroupName,
		[parameter(Mandatory=$False)]
		[string]$DatabaseName,
		[parameter(Mandatory=$false)]
		[string]$NewEdition,
		[parameter(Mandatory=$False)]
		[string]$NewServiceObjective,
		[parameter(Mandatory=$False)]
		[string]$NewDatabaseName,
		[parameter(Mandatory=$False)]
		[string]$AzureProfilePath,
		[parameter(Mandatory=$false)]
		[switch]$ChangeEdition,
		[parameter(Mandatory=$false)]
		[switch]$RenameDatabase,
		[parameter(Mandatory=$false)]
		[switch]$SetAdminPassword,
		[parameter(Mandatory=$false)]
		[string]$NewAdminPassword
		
	)

	Set-AzureProfile -AzureProfilePath $AzureProfilePath
	
	if($DatabaseName.Length -gt 0)
	{
		$d = Get-AzureRmSqlDatabase -DatabaseName $databasename -ServerName $ServerName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue -ErrorVariable dberror
	}

	$s = Get-AzureRmSqlServer -ServerName $ServerName -ResourceGroupName $ResourceGroupName
	
	#Rename database
	if($RenameDatabase)
	{
		Write-Host "Renaming database $DatabaseName to $NewDatabaseName..." -ForegroundColor Green
		Set-AzureRmSqlDatabase -ServerName $ServerName -DatabaseName $DatabaseName -NewName $NewDatabaseName -ResourceGroupName $ResourceGroupName
	}

	if($ChangeEdition)
	{
		Write-Host "Modifying edition of $DatabaseName to $NewEdition..." -ForegroundColor Green
		$d | Set-AzureRmSqlDatabase -Edition $NewEdition -RequestedServiceObjectiveName $NewServiceObjective

	}

	if($SetAdminPassword)
	{
		Write-Host "Modifying Administrator Password for Server $ServerName.." -ForegroundColor Green
		$s| Set-AzureRmSqlServer -SqlAdministratorPassword (ConvertTo-SecureString -String $NewAdminPassword -AsPlainText -Force)
	}
	
}

function Enable-AzureSqlDatabaseDiagnosticLogs
{
param
	(
		[string]$diagnosticsettingname="LogEverything",
		[string]$resourcegroupname,
		[string]$servername,
		[string]$databasename,
		[string]$storageaccountname,
		[switch]$createstorageaccount,
		[string]$Logs,
		[string]$metric="Basic",
		[boolean]$enable,
		[switch]$all,
		[switch]$enableretention,
		[int]$retentiondays=10,
		[string]$loganalyticsworkspacename,
		[switch]$createloganalyticsws,
		[string]$AzureProfilePath

)

Set-AzureProfile -AzureProfilePath $AzureProfilePath
$categories = New-Object System.Collections.Generic.List[string]
foreach($category in $logs.Split(","))
{
    $categories.Add($category)
    
}

#get azure sql database id 
$SqlResource = Get-AzSqlDatabase -DatabaseName $databasename -ServerName $servername -ResourceGroupName $resourcegroupname

if(![string]::IsNullOrEmpty($storageaccountname))
{

$_enableretention = $False
if($enableretention)
{ $_enableretention = $True }

if($createstorageaccount)
{
    $storageaccountname = $storageaccountname + (Get-Random).ToString()
    Create-AzureStorageAccount -storageaccountname $storageaccountname `
    -resourcegroupname $resourcegroupname `
    -location $SqlResource.Location `
    -skuname "Standard_LRS" `
    -AzureProfilePath E:\SQLAzureToolkit\MyAzureProfile.json

}

$Storageaccountid = (Get-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname).Id


#enable all metric and log
if($all -eq $true)
{
    $ds = Set-AzDiagnosticSetting -ResourceId $SqlResource.ResourceId `
    -Name $diagnosticsettingname `
    -StorageAccountId $Storageaccountid `
    -Enabled $enable `
    -RetentionInDays $retentiondays `
    -RetentionEnabled $_enableretention



}else
{
     $ds = Set-AzDiagnosticSetting -ResourceId $SqlResource.ResourceId `
     -Name $diagnosticsettingname `
     -StorageAccountId $Storageaccountid `
     -Category $categories `
     -MetricCategory $metric `
     -Enabled $enable `
     -RetentionInDays $retentiondays `
     -RetentionEnabled $_enableretention

}


}
if(![string]::IsNullOrEmpty($loganalyticsworkspacename))
{
	$loganalyticsworkspacename = $loganalyticsworkspacename + (Get-Random).ToString()
	#create analytics 
	if($createloganalyticsws)
	{
		Write-Host "Creating log analytics workspace $loganalyticsworkspacename.." -ForegroundColor Green
		 New-AzOperationalInsightsWorkspace -ResourceGroupName $SqlResource.ResourceGroupName `
		-Name $loganalyticsworkspacename `
		-Location $SqlResource.Location `
		-Sku "Standard"
	}
	$ws = Get-AzOperationalInsightsWorkspace -ResourceGroupName $SqlResource.ResourceGroupName -Name $loganalyticsworkspacename
	#set diagnostic setting
	Write-host "Create Diagnostic Setting.." -ForegroundColor Green
	$ds = Set-AzDiagnosticSetting -ResourceId $SqlResource.ResourceId `
	-Name $diagnosticsettingname `
	-WorkspaceId $ws.ResourceId `
	-Enabled $True `
	-Category $categories

}
#display the logged categories
#$ds = Get-AzDiagnosticSetting -ResourceId $SqlResource.ResourceId -Name $diagnosticsettingname
$ds.Logs | Where-Object { $_.Enabled -eq "True" } | Select Category,Enabled | Format-Table
$ds.Metrics | Where-Object { $_.Enabled -eq "True" } | Select Category,Enabled | Format-Table

}
