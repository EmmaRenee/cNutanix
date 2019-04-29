enum Ensure
{
   Absent
   Present
}

Configuration NutanixVM
{
    Param (
        [Parameter(Mandatory=$true)]
        [PSCredential]
        $ClusterCredential
    )
    
    Import-DscResource -ModuleName cNutanix -ModuleVersion 0.1.3

    Node $ConfigurationData.AllNodes.NodeName
    {
        Foreach ($vm in $ConfigurationData.VMs)
        {
            NewVM $vm.vmName
            {
                Ensure                  = [Ensure]::Present
                vmName                  = [string]$vm.vmName
                Description             = [string]$vm.Description
                NumberOfVCpu            = [int]$vm.NumberOfVCpu
                NumberOfCoresPerVCpu    = [int]$vm.NumberOfCoresPerVCpu
                MemoryMB                = [int]$vm.MemoryMB
                VmCustomizationConfig   = [string]$vm.VmCustomizationConfig
                ClusterUri              = [string]$ConfigurationData.AllNodes.ClusterURI
                ClusterCredential       = [PSCredential]$ClusterCredential
            }

            Foreach ($disk in $vm.Disks)
            {
                If ($disk.Type -eq 'Disk')
                {
                    NewVMDisk $($vm.vmName.replace('.test.lab','') + '-SCSI-' + $disk.Index)
                    {
                        Ensure              = [Ensure]::Present
                        vmName              = [string]$vm.vmName
                        BusId               = [string]$($vm.vmName.replace('.test.lab','') + '-SCSI-' + $disk.Index)
                        DiskSizeGB          = [int]$disk.DiskSizeGB
                        ContainerName       = [string]$disk.ContainerName
                        SourceVmName        = [string]$disk.SourceVmName
                        ClusterUri          = [string]$ConfigurationData.AllNodes.ClusterURI
                        ClusterCredential   = [PSCredential]$ClusterCredential
                        DependsOn           = "[NewVM]$($vm.vmName)"
                    }
                }
                else 
                {
                    NewVMDisk $($vm.vmName.replace('.test.lab','') + '-IDE-' + $disk.Index)
                    {
                        Ensure              = [Ensure]::Present
                        vmName              = [string]$vm.vmName
                        BusId               = [string]$($vm.vmName.replace('.test.lab','') + '-IDE-' + $disk.Index)
                        ContainerName       = [string]$disk.ContainerName
                        ClusterUri          = [string]$ConfigurationData.AllNodes.ClusterURI
                        ClusterCredential   = [PSCredential]$ClusterCredential
                        DependsOn           = "[NewVM]$($vm.vmName)"
                    }
                } 
            }
            
            Foreach ($nic in $vm.NICs)
            {
                NewVMNic $($vm.vmName.replace('.test.lab','') + '-Ethernet')
                {
                    Ensure              = [Ensure]::Present
                    vmName              = [string]$vm.vmName
                    vlanID              = [int]$nic.vlanID
                    vlanName            = [string]$nic.vlanName
                    ClusterUri          = [string]$ConfigurationData.AllNodes.ClusterURI
                    ClusterCredential   = [PSCredential]$ClusterCredential
                    DependsOn           = "[NewVM]$($vm.vmName)"
                }
            }
            
        }
    }
}

$ClusterUser = 'pshtest'
$credential = Get-Credential -Message 'Nutanix Cluster Credential' -UserName $ClusterUser
NutanixVM -ConfigurationData .\ConfigData.psd1 -OutputPath .\ -ClusterCredential $credential
Start-DscConfiguration .\ -Wait -Verbose -Force