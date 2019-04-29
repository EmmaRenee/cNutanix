# cNutanix: Automated VM Provisioning

cNutanix is a PowerShell Desired State Configuration (DSC) Resource Module enabling the automated provisioning of Nutanix virtual machines, including the creation of VM Disk's, and VM NIC's. This module includes three resources: 

* NewVM
* NewVMDisk
* NewVMNic

## NewVM

````` PowerShell
NewVM [String] #ResourceName
{
    Ensure                  = [string]{ Absent | Present }
    vmName                  = [string]
    MemoryMB                = [Int32]
    [Description            = [string]]
    [NumberOfVCpu           = [Int32]]
    [NumberOfCoresPerVCpu   = [Int32]]
    [VmCustomizationConfig  = [string]]
    ClusterUri              = [string]
    ClusterCredential       = [PSCredential]
    [DependsOn              = [string[]]]
}
`````

## NewVMDisk

````` PowerShell
NewVMDisk [String] #ResourceName
{
    Ensure              = [string]{ Absent | Present }
    BusId               = [string]
    vmName              = [string]
    ContainerName       = [string]
    [DiskSizeGB         = [Int32]]
    [SourceVmName       = [string]]
    ClusterUri          = [string]
    ClusterCredential   = [PSCredential]
    [DependsOn          = [string[]]]
}
`````

## NewVMNic

````` PowerShell
NewVMNic [String] #ResourceName
{    
    Ensure              = [string]{ Absent | Present }
    vmName              = [string]
    [vlanID             = [Int32]]
    [vlanName           = [string]]
    ClusterUri          = [string]
    ClusterCredential   = [PSCredential]
    [DependsOn          = [string[]]]
}
`````