Function New-NutanixDiskObject
{
    [CmdletBinding()]
    Param (
        # UUID of Virtual Machine
        [Parameter(Mandatory=$true)]
        [string]
        $vmUuid,

        # UUID of Virtual Machine to Clone
        [Parameter(Mandatory=$false)]
        [string]
        $SourceVmUuid,

        # Bus index to mount drive
        [Parameter(Mandatory=$true)]
        [int]
        $Index,

        # VM Disk size in GB
        [Parameter(Mandatory=$false)]
        [int]
        $diskSizeGB,

        # Storage Container UUID
        [Parameter(Mandatory=$false)]
        [string]
        $containerUuid,

        # Type of Device (determines bus type)
        [Parameter(Mandatory=$true)]
        [ValidateSet('Disk','CD-Rom')]
        [string]
        $DeviceType
    )

    $obj =  New-Object PSCustomObject -Property @{
        uuid     = $vmUuid
        vm_disks = $(New-Object -TypeName System.Collections.ArrayList)
    }

    If ($DeviceType -eq 'Disk')
    {
        $disk_address = New-Object PSCustomObject -Property @{
            device_bus = 'SCSI'
            device_index = $Index
        }

        If ($SourceVmUuid) 
        {
            $source = Get-NTNXVirtualDisk -Id (Get-NTNXVMDisk -Vmid $vmUuid | Where-Object { $_.id -eq 'scsi-0' }).vmdiskuuid

            $vm_disk_clone = New-Object PSCustomObject -Property @{
                disk_address = New-Object PSCustomObject -Property @{
                    device_bus = 'SCSI'
                    device_index = 0
                    vmdisk_uuid = $source.uuid
                }
                minimum_size = $($diskSizeGB * 1024 * 1024 *1024)
                storage_container_uuid = $source.containerUuid
            }

            $disk = New-Object PSCustomObject -Property @{
                disk_address = $disk_address
                is_cdrom = $false
                is_empty = $false
                is_scsi_pass_through = $true
                is_thin_provisioned = $true
                vm_disk_clone = $vm_disk_clone
            }
        }
        Else 
        {
            $vm_disk_create = New-Object PSCustomObject -Property @{
                size = $($diskSizeGB * 1024 * 1024 * 1024)
                storage_container_uuid = $containerUuid
            }
            
            $disk = New-Object PSCustomObject -Property @{
                disk_address = $disk_address
                is_cdrom = $false
                is_empty = $false
                is_scsi_pass_through = $true
                is_thin_provisioned = $true
                vm_disk_create = $vm_disk_create
            }
        }
    }
    ElseIf ($DeviceType -eq 'CD-Rom')
    {
        $disk_address = New-Object PSCustomObject -Property @{
            device_bus = 'IDE'
            device_index = $Index
        }
        
        $disk = New-Object PSCustomObject -Property @{
            disk_address = $disk_address
            is_cdrom = $true
            is_empty = $true
            is_scsi_pass_through = $true
        }
    }

    $obj.vm_disks.Add($disk)

    return $obj | ConvertTo-Json -Depth 4
}

# disk test
#Write-host "`n`rTesting Disk Object:`n`r" -ForegroundColor red
#$disk = New-NutanixDiskObject -vmUuid '587e29e5-4abf-4ccd-b4d4-1e5aecae88a7' -Index 5 -DiskSizeGB 80 -containerUuid '28f7f81a-d193-47c2-887f-0ac38fcfb323' -DeviceType 'Disk'
#$disk[1]

# disk clone test
#Write-host "`n`rTesting Disk Clone Object:`n`r" -ForegroundColor red
#$disk = New-NutanixDiskObject -vmUuid '587e29e5-4abf-4ccd-b4d4-1e5aecae88a7' -Index 0 -DiskSizeGB 80 -containerUuid '28f7f81a-d193-47c2-887f-0ac38fcfb323' -DeviceType 'Disk' -SourceVmUuid 'f8ac8007-c382-4fe6-abd3-1635b09210c0'
#$disk[1]

# cd-rom test
#Write-Host "`n`rTesting CD-Rom Object:`n`r" -ForegroundColor red
#$disk = New-NutanixDiskObject -vmUuid 'f8ac8007-c382-4fe6-abd3-1635b09210c0' -Index 5 -DeviceType 'CD-Rom'
#$disk[1]