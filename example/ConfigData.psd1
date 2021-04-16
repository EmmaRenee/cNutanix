@{
    AllNodes = @(
        @{
            NodeName                    = '*'
            PsDscAllowDomainUser        = $true
            PsDscAllowPlainTextPassword = $true
        }
        @{
            NodeName            = 'localhost'
            ClusterUri          = 'mycluster.mydomain.com'
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
