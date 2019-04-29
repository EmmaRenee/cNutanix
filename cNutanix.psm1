# Import Nutanix cmdlets
$snapin = 'NutanixCmdletsPsSnapin'
Add-PSSnapin -Name $snapin

# Get all functions in module
$functions = Get-ChildItem -Path "$PSScriptRoot\function" -Include "*.Function.ps1" -Recurse

# Import all functions.
Foreach ($function in $functions)
{
    $path = $function.Name

    Write-Host "Importing function: $path"
    . "$PSScriptRoot\function\$path"
}

enum Ensure
{
    Absent
    Present
}

[DscResource()]
class NewVM
{
    [DscProperty(Mandatory)]
    [Ensure]$Ensure

    [DscProperty(key)]
    [string]$vmName

    [DscProperty(Mandatory=$false)]
    [int]$NumberOfVCpu = 1

    [DscProperty(Mandatory=$false)]
    [int]$NumberOfCoresPerVCpu = 1

    [DscProperty(Mandatory)]
    [int]$MemoryMB

    [DscProperty(Mandatory=$false)]
    [string]$Description

    [DscProperty(Mandatory)]
    [string]$ClusterUri

    [DscProperty(Mandatory)]
    [PSCredential]$ClusterCredential

    [DscProperty(Mandatory=$false)]
    [string]$VmCustomizationConfig

    [NewVM] Get()
    {
        # Open Connection
        $cluster = $this.OpenConnection()

        # Get VM information
        #$vm = Get-NTNXVM -NutanixClusters $cluster | Where-Object { $_.vmName -eq $this.vmName }
        $vm = Get-NTNXVM | Where-Object { $_.vmName -eq $this.vmName }

        # Close Connection
        $this.CloseConnection()

        # Return test result
        return $vm
    }

    [bool] Test()
    {
        # Open Connection
        $cluster = $this.OpenConnection()

        # Check if VM exists
        #$vm = Get-NTNXVM -NutanixClusters $cluster | Where-Object { $_.vmName -eq $this.vmName }
        $vm = Get-NTNXVM | Where-Object { $_.vmName -eq $this.vmName }

        # Close Connection
        $this.CloseConnection()

        # Return test result
        return [bool]$vm
    }

    [void] Set()
    {
        # Open Connection
        $cluster = $this.OpenConnection()

        # Create new virtual machine
        New-NTNXVirtualMachine  -Name $this.vmName `
                                -NumVcpus $this.NumberOfVCpu `
                                -NumCoresPerVcpu $this.NumberOfCoresPerVCpu `
                                -MemoryMb $this.MemoryMB `
                                -Description $this.Description `
                                -VmCustomizationConfig $this.VmCustomizationConfig

        Write-Verbose 'Sleep for 10 seconds'
        Start-Sleep -Seconds 10

        # Close Connection
        $this.CloseConnection()
    }

    [void] OpenConnection()
    {
        Write-Verbose "Connecting to cluster: $($this.ClusterUri)"
        
        # Credentials
        $user = $this.ClusterCredential.UserName
        $pass = ConvertTo-SecureString -String $this.ClusterCredential.GetNetworkCredential().password -AsPlainText -Force

        # Open connection to Nutanix Cluster
        $out = Connect-NutanixCluster -Server $this.ClusterUri -UserName $this.ClusterCredential.UserName -pass $pass -AcceptInvalidSSLCerts -ForcedConnection

        Write-Verbose $out
    }

    [void] CloseConnection()
    {
        Write-Verbose "Closing cluster connection: $($this.ClusterUri)"

        # Reset connection to Nutanix Cluster
        Disconnect-NutanixCluster -Server $this.ClusterUri
    }
}

[DscResource()]
class NewVMDisk
{
    [DscProperty(Mandatory)]
    [Ensure]$Ensure

    [DscProperty(key)]    
    [ValidateNotNullOrEmpty()]
    [string]$BusId

    [DscProperty(Mandatory)]
    [string]$vmName

    [DscProperty(Mandatory=$false)]
    [string]$SourceVmName

    [DscProperty(Mandatory=$false)]
    [int]$DiskSizeGB

    [DscProperty(Mandatory)]
    [string]$ContainerName

    [DscProperty(Mandatory)]
    [string]$ClusterUri

    [DscProperty(Mandatory)]
    [PSCredential]$ClusterCredential

    [NewVMDisk] Get()
    {
        # Establish connection with Nutnix cluster
        $this.OpenConnection()
        
        $DiskIndex = $this.BusId.Replace($($this.vmName.replace('.test.lab','') + '-'),'')

        # Get the VmID of the VM
        $vmId = (Get-NTNXVM | Where-Object {$_.vmName -eq $this.vmName}).uuid

        Write-Verbose "VM ID: $vmid"

        # Get VM Disk
        $disk = Get-NTNXVMDisk -Vmid $vmId | Where-Object { $_.id -eq $DiskIndex }

        If ($disk.count -ne 0)
        {
            $obj = New-Object PSObject -Property @{
                uuid = $disk.vmDiskUuid
                isCdrom    = [bool]$(If ($this.Type -eq 'CD-Rom'){ $true } Else { $false })
                isEmpty    = [bool]$(If ($this.Type -eq 'CD-Rom'){ If ($this.ImageName) { $true } Else { $false } } Else { $false })
                BusType    = $DiskIndex.split('-')[0]
                Index      = $this.Index
                vmDiskSize = $(Get-NTNXVirtualDisk -Id $disk.vmDiskUuid).diskCapacityInBytes
            }
        }
        else
        {
            $obj = $null
        }

        # Close cluster connection
        $this.CloseConnection()

        return $obj
    }

    [bool] Test()
    {
        # Establish connection with Nutnix cluster
        $this.OpenConnection()

        $DiskIndex = $this.BusId.Replace($($this.vmName.replace('.test.lab','') + '-'),'')

        # Get the VmID of the VM
        $vmId = (Get-NTNXVM | Where-Object {$_.vmName -eq $this.vmName}).uuid

        Write-Verbose "VM ID: $vmid"

        If ($DiskIndex -match 'scsi')
        {
            # Get VM Disk
            $vmDiskUuid = (Get-NTNXVMDisk -Vmid $vmId | Where-Object { $_.id -eq $DiskIndex }).vmDiskUuid

            If ($vmDiskUuid)
            {
                $disk = Get-NTNXVirtualDisk -id $vmDiskUuid

                If ($disk.diskCapacityInBytes -ge $($this.DiskSizeGB / 1024 / 1024 / 1024))
                {
                    $disk = $true
                }
                else
                {
                    $disk = $false
                }
            }
            Else
            {
                $disk = $false
            }
        }
        else
        {
            # Get VM Disk
            $vmDisk = Get-NTNXVMDisk -Vmid $vmId | Where-Object { $_.id -eq $DiskIndex }

            If ($vmDisk.isCdrom -eq $true)
            {
                $disk = $true
            }
            Else
            {
                $disk = $false
            }
        }

        # Close cluster connection
        $this.CloseConnection()

        return [bool]$disk
    }

    [void] Set()
    {
        # Establish connection with Nutnix cluster
        $this.OpenConnection()

        $DiskIndex = $this.BusId.Replace($($this.vmName.replace('.test.lab','') + '-'),'')

        # Get the VmID of the VM
        $vmId = (Get-NTNXVM | Where-Object {$_.vmName -eq $this.vmName}).uuid

        Write-Verbose "VM ID: $vmid"

        If ($DiskIndex.split('-')[0] -eq 'ide')
        {
            Write-Verbose "Device Bus: $DiskIndex"
            
            $disk = (New-NutanixDiskObject -vmUuid $vmId -Index $DiskIndex.split('-')[1] -DeviceType 'CD-Rom')[1]
            Write-Verbose $disk
        }
        Else
        {
            Write-Verbose "Device Bus: $DiskIndex"

            $containerUuid = (Get-NTNXContainer | Where-Object { $_.name -eq $this.ContainerName }).containerUuid
            Write-Verbose "Container ID: $($containerUuid)"

            If ($this.SourceVmName)
            {
                # Get the VmID of the VM
                $SourceVmId = (Get-NTNXVM | Where-Object {$_.vmName -eq $this.SourceVmName}).uuid
                Write-Verbose "Source VM: $($SourceVmId)"

                $disk = (New-NutanixDiskObject -vmUuid $vmId -Index $DiskIndex.split('-')[1] -DiskSizeGB $this.DiskSizeGB -containerUuid $containerUuid -DeviceType 'Disk' -SourceVmUuid $SourceVmId)[1]
                Write-Verbose $disk
            }
            Else
            {
                $disk = (New-NutanixDiskObject -vmUuid $vmId -Index $DiskIndex.split('-')[1] -DiskSizeGB $this.DiskSizeGB -containerUuid $containerUuid -DeviceType 'Disk')[1]
                Write-Verbose $disk
            }
        }

        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # Credentials
        $user = $this.ClusterCredential.UserName
        $pass = $this.ClusterCredential.GetNetworkCredential().password

        $Uri = "https://$($this.ClusterUri):9440/api/nutanix/v2.0/vms/$vmId/disks/attach/"
        $Header = @{
            'Authorization' = 'Basic ' + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes( $User + ':' + $pass ));
            'Accept' = 'application/json'
            'Content-Type' = 'application/json'
        }

        Write-Verbose 'Sending API query'
        Invoke-RestMethod -Method Post -Uri $Uri -Headers $Header -Body $disk

        # Close cluster connection
        $this.CloseConnection()
    }

    [void] OpenConnection()
    {
        Write-Verbose "Connecting to cluster: $($this.ClusterUri)"
        
        # Credentials
        $user = $this.ClusterCredential.UserName
        $pass = ConvertTo-SecureString -String $this.ClusterCredential.GetNetworkCredential().password -AsPlainText -Force

        # Open connection to Nutanix Cluster
        $out = Connect-NutanixCluster -Server $this.ClusterUri -UserName $this.ClusterCredential.UserName -pass $pass -AcceptInvalidSSLCerts -ForcedConnection

        Write-Verbose $out
    }

    [void] CloseConnection()
    {
        Write-Verbose "Closing cluster connection: $($this.ClusterUri)"

        # Reset connection to Nutanix Cluster
        Disconnect-NutanixCluster -Server $this.ClusterUri
    }
}

[DscResource()]
class NewVMNic
{
    [DscProperty(Mandatory)]
    [Ensure]$Ensure

    [DscProperty(key)]
    [string]$vmName

    [DscProperty(Mandatory=$false)]
    [string]$vlanName

    [DscProperty(Mandatory=$false)]
    [int]$vlanID = 0

    [DscProperty(Mandatory)]
    [string]$ClusterUri

    [DscProperty(Mandatory)]
    [PSCredential]$ClusterCredential
    
    [NewVMNic] Get()
    {
        # Establish connection with Nutnix cluster
        $this.OpenConnection()

        # Get the VmID of the VM
        $vmId = (Get-NTNXVM | Where-Object {$_.vmName -eq $this.vmName}).uuid

        # Get Network UUID
        If ($this.vlanID)
        {
            $network = Get-NTNXNetwork | Where-Object { $_.vlanId -eq $this.vlanID }
        }
        ElseIf ($this.vlanName)
        {
            $network = Get-NTNXNetwork | Where-Object { $_.Name -eq $this.vlanName }
        }

        # Get NIC info
        $nic = Get-NTNXVMNIC -Vmid $vmid | Where-Object { $_.networkUuid -eq $network.uuid }

        # Close cluster connection
        $this.CloseConnection()

        return $nic
    }

    [bool] Test()
    {
        # Establish connection with Nutnix cluster
        $this.OpenConnection()

        # Get the VmID of the VM
        $vmId = (Get-NTNXVM | Where-Object {$_.vmName -eq $this.vmName}).uuid

        # Get Network UUID
        If ($this.vlanID)
        {
            $network = Get-NTNXNetwork | Where-Object { $_.vlanId -eq $this.vlanID }
        }
        ElseIf ($this.vlanName)
        {
            $network = Get-NTNXNetwork | Where-Object { $_.Name -eq $this.vlanName }
        }

        # Get NIC info
        $nic = [bool](Get-NTNXVMNIC -Vmid $vmid | Where-Object { $_.networkUuid -eq $network.uuid }).count

        # Close cluster connection
        $this.CloseConnection()

        return [bool]$nic
    }

    [void] Set()
    {
        # Establish connection with Nutnix cluster
        $this.OpenConnection()

        # Get the VmID of the VM
        $vmId = (Get-NTNXVM | Where-Object {$_.vmName -eq $this.vmName}).uuid

        # Get Network UUID
        If ($this.vlanID)
        {
            $network = Get-NTNXNetwork | Where-Object { $_.vlanId -eq $this.vlanID }
        }
        ElseIf ($this.vlanName)
        {
            $network = Get-NTNXNetwork | Where-Object { $_.Name -eq $this.vlanName }
        }
        Else
        {
            Write-Verbose 'No VLAN specified - terminating'
            break
        }

        # Set NIC for VM on default vlan (Get-NTNXNetwork -> NetworkUuid)
        $nic = New-NTNXObject -Name VMNicSpecDTO
        $nic.networkUuid = $network.uuid

        # Adding a Nic
        Add-NTNXVMNic -Vmid $vmId -SpecList $nic

        # Close cluster connection
        $this.CloseConnection()
    }

    [void] OpenConnection()
    {
        Write-Verbose "Connecting to cluster: $($this.ClusterUri)"
        
        # Credentials
        $user = $this.ClusterCredential.UserName
        $pass = ConvertTo-SecureString -String $this.ClusterCredential.GetNetworkCredential().password -AsPlainText -Force

        # Open connection to Nutanix Cluster
        $out = Connect-NutanixCluster -Server $this.ClusterUri -UserName $this.ClusterCredential.UserName -pass $pass -AcceptInvalidSSLCerts -ForcedConnection

        Write-Verbose $out
    }

    [void] CloseConnection()
    {
        Write-Verbose "Closing cluster connection: $($this.ClusterUri)"

        # Reset connection to Nutanix Cluster
        Disconnect-NutanixCluster -Server $this.ClusterUri
    }
}