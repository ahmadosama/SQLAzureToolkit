# SQLAzureToolkit
PowerShell module to perform Administrative tasks for Azure SQL Database

Download and copy the module to your module directory. To find out the default module directory execute the below powershell command

$env:PSModulePath

Import the module using the below command

Import-Module SQLAzureToolKit

Provision a new Azure SQL Database

Create-AzureSQLDatabase -azuresqlservername myazuresqlserver -resourcegroupname myresourcegroup -databasename myazuredb `
-login dpladmin -password password -location "Southeast Asia"

The above powershell command will create a new SQL Azure database myazuredb in Azure SQL Server myazuresqlserver in resource
group myresourcegroup at location Southeast Asia.

The Azure Resource Group, Azure SQL Server and Azure SQL Database are created only if they doesn't exists at the given location. 

Provision a new Azure Resource Group

Create-AzureResourceGroup -resourcegroupname dpl -location "Southeast Asia"

The above command will create a new Azure Resource group dpl in Southeast Asia if it doens't exists. 

Provision a new Azure SQL Server 

Create-AzureSQLServer -azuresqlservername dplserver -resourcegroupname dpl -login dpladmin -password password `
-location "Southeast Asia"

The above command will create a new Azure SQL Server dplserver in resource group dpl at location Southeast Asia, if it doesn't exists.
If resource group provided doesn't exists, it's not automatically created. 

Configure Firewall Rule for Azure SQL Server

Set-AzureSQLServerFireWallRule -rulename "home" -azuresqlservername myazureserver -resourcegroupname dpl -startip 100.10.10.100 `
-endip 100.10.10.200

The above command will add a new firewall rule "home" to myazureserver with IP range as specified by startip and endip.
If startip and endip aren't specified, public ip is added to the firewall rule.

Delete Azure Resource Group

Delete-AzureResourceGroup -resourcegroupname dpl -location "Southeast Asia"

The above command will delete the Azure Resource group dpl at Southeast Asia, if it exists. 

Delete Azure SQL Server

Delete-AzureSQLServer -azuresqlservername myazureserver -resourcegroupname dpl

The above command will delete an Azure SQL Server myazureserver in resource group dpl, if it exists.

Delete Azure SQL Database

Delete-AzureSQLDatabase -azuresqlservername myazureserver -resourcegroupname dpl -databasename myazuredb

The above command will delete Azure SQL Database myazuredb in Azure SQL Server myazureserver in resource group dpl, if it exists.

Delete Azure SQL Server Firewall Rule

Delete-AzureSQLServerFirewallRule -azuresqlservername myazureserver -resourcegroupname dpl -rulename home

The above command will delete the Azure SQL Server firewall rule home for Azure SQL Server myazureserver in resource group dpl.
