# Example Configuration

This folder contains an example Desired State Configuration (DSC) script, which demonstrates the basic use case of all three DSC resources (NewVM, NewVMDisk, and NewVMNic).

This example consists of two parts.
1. PowerShell Manifest file (psd1)
2. PowerShell Configuration Script file (ps1)

In this readme I will walk you through what each of these are and how you can use these resources to spin up Nutanix virtual machines.

## PowerShell Manifest

The manifest file is very much comparable to a json file, in terms of purpose and structure. It contains lists of properties which we will use to define our virtual machines.

This file is broken down into a few logical blocks/lists, to make it a little easier to read (and yes, I am speaking of arrays and hashtables here).

### AllNodes

The first block is the "AllNodes" array. This contains two hashtables. The first contains global setting for our script.

````` PowerShell
@{
    NodeName                    = '*'       # Block applies to all nodes
    PsDscAllowDomainUser        = $true     # Permit domain credentials in configuration
    PsDscAllowPlainTextPassword = $true     # Permit plain text passwords in configuration (Mandatory!)
}
`````

**NodeName**: In this block NodeName is set to the "*" wildcard, making the properties containted in this hashtable applicable to all nodes in our script.

**PsDscAllowDomainUser**: If you intend on using a domain credential to execute your script, this setting must be set to $true.

**PsDscAllowPlainTextPassword**: While our passwords will be encoded as a PowerShell Secure String object (hashed), the script does still treat these as if they were plain text. Therefor we must allow this execption for the script execute successfully.

The next block contains settings specific to the node processing our configuration. This node must be a Windows machine running Windows PowerShell 5.x. It must have the cNutanix DSC resource module installed, and it also must have the Nutanix cmdlets PS Snapin installed.

````` PowerShell
@{
    NodeName            = 'localhost'       # Mandatory - Name of system executing script (localhost is sufficient)
    ClusterUri          = '10.0.8.19'     # Mandatory - Cluster VIP
}
`````

**NodeName**: This contains the name of Windows machine executing the script. This could be the box you authoring your script on. The parameter can generally be left as 'localhost', as the name of this machine isn't otherwise relevant to our configuration.

**ClusterUri**: This is name or IP of the Nutanix cluster we are working with. I generally recommend using the VIP of the cluster here.

All of this is wrapped in the "AllNodes" array, which looks like this:

````` PowerShell
@{
    AllNodes = @(
        @{
            NodeName                    = '*'
            PsDscAllowDomainUser        = $true
            PsDscAllowPlainTextPassword = $true
        }
        @{
            NodeName            = 'localhost'
            ClusterUri          = '10.0.8.19'
        }
    )
}
`````

Now that this is done, we can get into the meat and potatoes of what we are here for. The automated provisioning of virtual machines on Nutanix.

### VMs

The next block is aptly named "VMs". This block can contains an array which contain multiple the properties for multiple VM's, each defined it's own hashtable.

````` PowerShell
VMs = @(
    @{
        vmName                  = 'TestVM'                  # Mandatory
        Description             = 'This is a test VM'       # Optional
        NumberOfVCpu            = 2                         # Optional - default: 1
        NumberOfCoresPerVCpu    = 2                         # Optional - default: 1
        MemoryMB                = 4096
        # Optional customization script: VmCustomizationConfig   = [string]
        Disks = @(...)
        NICs = @(...)
    }
)
`````

This example shows most of it we will need to define to create a VM. You may have noticed that the Disks and NICs properties contain array's. I'll get to those in a bit.

**vmName**: This property contain the displayname for your VM. This is what you will see displayed in the table of VM's in the Nutanix Prism GUI. This is a Mandatory property.

**Description**: This is an optional property, which permits you to specify a description for your VM.

**NumberOfVCpu**: This is the number of vCpu's you wish to assign to the VM. This property is optional and will default to `1`, if not specified.

**NumberOfCoresPerVCpu**: This is the number of cores you wish to assign per assigned vCpu. This property is optional and will default to `1`, if not specified.

**MemoryMB**: This is the amount of RAM you wish to assign in MB's. This is a Mandatory property.

**VmCustomizationConfig**: This an optional parameter which allows you specify what Nutanix calls a Custom Script. For Windows machines this would be a Sysprep unattend file, whereas Linux would use Cloud-Init.

#### Disks

Disks contains an array of disks. Meaning you can define multiple disks here.

````` PowerShell
Disks = @(
    @{
        Type            = 'Disk'                    # Mandatory - must be 'Disk' or 'CD-Rom'
        Index           = 0                         # Mandatory - unique disk index
        DiskSizeGB      = 50                        # Mandatory for type 'Disk' that is not cloned
        ContainerName   = 'SelfServiceContainer'    # Mandatory - name of Nutanix storage container
        # Optional: SourceVmName = [string]
    }
)
`````

**Type**: This is a mandatory property. VM Disks on Nutanix can either be of the type `Disk` or `CD-Rom`. The property must match one of these values.

**Index**: This is the bus index the drive will be mounted at. These value is mandatory and must be unique. The first disk should be mounted at index '0'. Disks of the type `Disk` are mounted on the `SCSI` bus, whereas disks of the type `CD-Rom` are mounted on the `IDE` bus. So, if you have one of each, they should both have an index of `0`.

**DiskSizeGB**: While this property is optional, there are some instances where this property becomes mandatory. For instance if you are creating a new blank disk, you must specify a size. However, if this is a cloned drive, it is optional. For cloned drives this parameter is used to defined the minimum size of the disk. It is of course not applicable to disks of the type `CD-Rom`.

**ContainerName**: This property is mandatory regardless of disk type, and defines which Nutanix storage container the VM disk file will reside on.

**SourceVmName**: The property is optional, and can be used to clone the primary disk `SCSI-0` of an existing VM.

> **Note to self:** Need to expand on the SourceVmName property to enable the cloning from image service, mounting of ISO's, and cloning of disks which aren't mounted on index 0.

#### NICs

Much like Disks, NICs contains an array of NIC's.

````` PowerShell
NICs = @(
    @{
        vlanID = 26    # Optional - must specify either vlanID or vlanName param
        # Alternatively: vlanName = [string]
    }
)
`````

**vlanID**: Specifies the numeric value of the desired VLAN to place the NIC on.

**vlanName**: If you do not know the numeric value, you can alternately specify the VLAN's name specified in Nutanix. The script will dynamically determine the numeric value associated with name specified.

> Both of these properties are optional, but you must specify one or the other in order to create a NIC.

### Completed VM hashtable

When we put all of this together, this looks like:

````` PowerShell
VMs = @(
    @{
        vmName                  = 'TestVM'
        Description             = 'This is a test VM'
        NumberOfVCpu            = 2
        NumberOfCoresPerVCpu    = 2
        MemoryMB                = 4096
        Disks = @(
            @{
                Type            = 'Disk'
                Index           = 0
                DiskSizeGB      = 50
                ContainerName   = 'SelfServiceContainer'
            }
            @{
                Type            = 'CD-Rom'
                Index           = 0
                ContainerName   = 'SelfServiceContainer'
            }
        )
        NICs = @(
            @{
                vlanID          = 26
            }
        )
    }
)
`````

### Finished product

This is what your manifest should like when you put it all together.

````` PowerShell
@{
    AllNodes = @(
        @{
            NodeName                    = '*'
            PsDscAllowDomainUser        = $true
            PsDscAllowPlainTextPassword = $true
        }
        @{
            NodeName            = 'localhost'
            ClusterUri          = '10.0.8.19'
        }
    )

    VMs = @(
        @{
            vmName                  = 'TestVM'
            Description             = 'This is a test VM'
            NumberOfVCpu            = 2
            NumberOfCoresPerVCpu    = 2
            MemoryMB                = 4096
            Disks = @(
                @{
                    Type            = 'Disk'
                    Index           = 0
                    DiskSizeGB      = 50
                    ContainerName   = 'SelfServiceContainer'
                }
                @{
                    Type            = 'CD-Rom'
                    Index           = 0
                    ContainerName   = 'SelfServiceContainer'
                }
            )
            NICs = @(
                @{
                    vlanID          = 26
                }
            )
        }
    )
}
`````

## PowerShell Configuration Script

The configuration script in it's most basic form is a declaritive document, defining the configuration of our resources in a very similar way to what we have done in the manifest above.

DSC configurations can have some imbeded logic, but most of the heavy lifting is down in the DSC resources contained within the cNutanix resource module.

Most of the logic you are going to see here is some foreach loops to iterate through the arrays of objects we defined in our manifest file.

> This example script is full featured, and shouldn't require to much in form of modification to be used in a production environment.
> You may however wish to expand on what has been done here by adding additional resources to this configuration.

### Configuration

When you open the configuration script, the first thing you will notice at the top of the files is a few lines creating an enum. An enum is a consice way to check parameters. In this case we are setting the possible values for the ensure parameter of our resouces.

````` PowerShell
enum Ensure
{
   Absent
   Present
}
`````

Right after the enum we get into the meet and potatoes of what will make all of this work - the configuration block. This block is structured much like a function, but it's resource blocks are declarative in nature.

To reiterate, this configuration can and does contain some logic, but most of the heavy lifting is done within the resource classes we are calling below. The classes do all of the big stuff in the background. You will be able to see much of what is happening when running a DSC configuration against a node.

````` PowerShell
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
`````

You will notice that the structure of this configuration isn't all to dissimilar to the manifest file we created preveously. There is some life logic imbeded however, to enable the configuration to iterate through all of the objects we defined in our manifest.

### PowerShell Script

Below the configuration you find a few lines of PowerShell script.

````` PowerShell
$ClusterUser = 'pshtest'
$credential = Get-Credential -Message 'Nutanix Cluster Credential' -UserName $ClusterUser
NutanixVM -ConfigurationData .\ConfigData.psd1 -OutputPath .\ -ClusterCredential $credential
Start-DscConfiguration .\ -Wait -Verbose -Force
`````

The first two lines define the credential we will be using to connect to the Nutanix cluster. This credential must have the required permissions to perform all of the actions we have defined in our configuration.

> You will want to change the $ClusterUser variable to contain you're user name.
> Domain credentials are supported in the user@domain format. Just like logging into Prism.

After this we execute the configuration script, feeding it the manifest file. The execution of this script will generate a MOF file. Think of a MOF file as a configartion file which defines the state of a system.

> To learn more about [MOF click here](https://en.wikipedia.org/wiki/Microsoft_Operations_Framework).

The last line finally executes our configuraion, but sending the MOF to local configuration manager (LCM) of the targeted node. In case of this example it's the local system.

> The LCM is an embeded part of Windows, which with the advent of PowerShell 6.x is now also available on Mac and Linux.
