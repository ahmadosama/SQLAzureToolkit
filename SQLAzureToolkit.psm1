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
        [string]$location,
        [string]$startip,
        [string]$endip
        )

	Try
	{
		#get current Azure context
		$context = Get-AzureRmContext -ErrorAction SilentlyContinue -ErrorVariable acerror
		
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
			$c=New-AzureRmSqlServer -ResourceGroupName $resourcegroupname -ServerName $azuresqlservername -Location $location -SqlAdministratorCredentials $(New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $login, $(ConvertTo-SecureString -String $password -AsPlainText -Force)) -ErrorAction SilentlyContinue -ErrorVariable createerror
            if($createerror -ne $null)
            {
                Write-Host $createerror -ForegroundColor Red
                
                return;
            }

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
		#get current Azure context
		$context = Get-AzureRmContext -ErrorAction SilentlyContinue -ErrorVariable acerror
		

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
				New-AzureRmSqlDatabase  -ResourceGroupName $resourcegroupname  -ServerName $azuresqlservername -DatabaseName $databasename -RequestedServiceObjectiveName $pricingtier -ErrorAction SilentlyContinue -ErrorVariable dberror
			}
			else
			{
				New-AzureRmSqlDatabase  -ResourceGroupName $resourcegroupname  -ServerName $azuresqlservername -DatabaseName $databasename -RequestedServiceObjectiveName $pricingtier -ElasticPoolName $elasticpool -ErrorAction SilentlyContinue -ErrorVariable dberror
			}
			                       
            if($dberror -eq $null)
	    	{
                Write-host "$databasename provisioned." -ForegroundColor Green
            }else
            {
                Write-Host $dberror -ForegroundColor Red
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