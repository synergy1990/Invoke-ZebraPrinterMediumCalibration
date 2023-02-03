# Required module: PoshRSJob. So first install this module by using an elevated PowerShell with the following command:
# Install-Module -Name PoshRSJob
function Test-OnlineFast
{
    param
    (
        # make parameter pipeline-aware
        [Parameter(Mandatory,ValueFromPipeline)]
        [string[]]
        $ComputerName,

        $TimeoutMillisec = 200
    )

    begin
    {
        # use this to collect computer names that were sent via pipeline
        [Collections.ArrayList]$bucket = @()
    
        # hash table with error code to text translation
        $StatusCode_ReturnValue = 
        @{
            0='Success'
            11001='Buffer Too Small'
            11002='Destination Net Unreachable'
            11003='Destination Host Unreachable'
            11004='Destination Protocol Unreachable'
            11005='Destination Port Unreachable'
            11006='No Resources'
            11007='Bad Option'
            11008='Hardware Error'
            11009='Packet Too Big'
            11010='Request Timed Out'
            11011='Bad Request'
            11012='Bad Route'
            11013='TimeToLive Expired Transit'
            11014='TimeToLive Expired Reassembly'
            11015='Parameter Problem'
            11016='Source Quench'
            11017='Option Too Big'
            11018='Bad Destination'
            11032='Negotiating IPSEC'
            11050='General Failure'
        }
    
    
        # hash table with calculated property that translates
        # numeric return value into friendly text

        $statusFriendlyText = @{
            # name of column
            Name = 'Status'
            # code to calculate content of column
            Expression = { 
                # take status code and use it as index into
                # the hash table with friendly names
                # make sure the key is of same data type (int)
                $StatusCode_ReturnValue[([int]$_.StatusCode)]
            }
        }

        # calculated property that returns $true when status -eq 0
        $IsOnline = @{
            Name = 'Online'
            Expression = { $_.StatusCode -eq 0 }
        }

        # do DNS resolution when system responds to ping
        $DNSName = @{
            Name = 'DNSName'
            Expression = { if ($_.StatusCode -eq 0) { 
                    if ($_.Address -like '*.*.*.*') 
                    { [Net.DNS]::GetHostByAddress($_.Address).HostName  } 
                    else  
                    { [Net.DNS]::GetHostByName($_.Address).HostName  } 
                }
            }
        }
    }
    
    process
    {
        # add each computer name to the bucket
        # we either receive a string array via parameter, or 
        # the process block runs multiple times when computer
        # names are piped
        $ComputerName | ForEach-Object {
            $null = $bucket.Add($_)
        }
    }
    
    end
    {
        # convert list of computers into a WMI query string
        $query = $bucket -join "' or Address='"
        
        Get-WmiObject -Class Win32_PingStatus -Filter "(Address='$query') and timeout=$TimeoutMillisec" |
        Select-Object -Property Address, $IsOnline, $DNSName, $statusFriendlyText
    }
    
}

function Invoke-ZebraPrinterMediumCalibration {
    $ZebraPrinters = @(
        # Put in your IP addresses here
        '192.168.1.50', '192.168.1.51', '192.168.1.52', '192.168.1.53',
        '192.168.1.54', '192.168.1.55', '192.168.1.56', '192.168.1.57'
    )
    
    $OnlineZebras = $ZebraPrinters | Test-OnlineFast | Where-Object {$_.Online -like "*True"}
    foreach ($Zebra in $OnlineZebras) {
        switch ($($Zebra.Address)) {
        # Put your printer names here as they are installed with on your print server
        # We need to do this because Zebra printers do not have a DNS name.
            "192.168.1.50" { $Zebra.DNSName = "ZEBRA-ONE" }
            "192.168.1.51" { $Zebra.DNSName = "ZEBRA-TWO" }
            "192.168.1.52" { $Zebra.DNSName = "ZEBRA-THREE" }
            "192.168.1.53" { $Zebra.DNSName = "ZEBRA-FOUR" }
            "192.168.1.54" { $Zebra.DNSName = "ZEBRA-FIVE" }
            "192.168.1.55" { $Zebra.DNSName = "ZEBRA-SIX" }
            "192.168.1.56" { $Zebra.DNSName = "ZEBRA-SEVEN" }
            "192.168.1.57" { $Zebra.DNSName = "ZEBRA-EIGHT" }
        }
    }
   
    $ScriptBlock = {
        Param($MyPrinterName)
        Write-Output "Processing: $($MyPrinterName)"
        $MyPrinter = Get-Printer -Name $MyPrinterName
        
        # Store the old drivername in a variable to be able to reset it again
        $OldDriver = (Get-PrinterDriver | Where-Object { ($_.Name -like "*$($MyPrinter.DriverName)*")})

        Write-Output "The old driver name is: $($OldDriver.Name)"
        Write-Output "---"

        Write-Output "Setting driver to text mode"
        $TempDriver = (Get-PrinterDriver | Where-Object { ($_.Name -like "*Generic*") -and ($_.Name -like "*Text*") })
        Start-Sleep -Milliseconds 500
        Write-Output "Temporarily using $($TempDriver.Name) as our driver"

        $MyPrinter | Set-Printer -DriverName $($TempDriver.Name) -ErrorAction SilentlyContinue

        $WaitTime = 500
        Start-Sleep -Milliseconds $WaitTime

        # Have a bit of a rest :)
        Write-Output "Waiting $WaitTime milliseconds"
        Start-Sleep -Milliseconds $WaitTime

        # Send the calibration code
        "~JC" | Out-Printer -Name $MyPrinter.Name

        # Have a bit of a rest :)
        Write-Output "Waiting $WaitTime milliseconds"
        Start-Sleep -Milliseconds $WaitTime

        # Set the old driver again
        $MyPrinter | Set-Printer -DriverName $($OldDriver.Name) -ErrorAction SilentlyContinue
       
        Write-Output "Now the driver is set back to: $($MyPrinter.DriverName)"
    }
    
    $OnlineZebras.DNSName | % { Start-RSJob -ScriptBlock $ScriptBlock -ArgumentList $_ | Out-Null }
    Get-RSJob | Wait-RSJob | Receive-RSJob
}

Get-Date
Invoke-ZebraPrinterMediumCalibration
Get-Date
