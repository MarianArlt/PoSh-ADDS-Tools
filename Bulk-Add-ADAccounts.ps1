    [CmdletBinding()]
    param (
        [parameter(mandatory)]
        [string] $Domain,

        [parameter()]
        [string] $Names = "Test_User",

        [parameter()]
        [string] $Password = "p@ssw0rd",

        [parameter()]
        [string] $OUPath = "OU_USR.OU_TEST",

        [parameter()]
        [int] $Create = 10,

        [parameter()]
        [switch] $Computer,

        [parameter()]
        [switch] $CSV,

        [parameter()]
        [string] $CSVDelimiter = ","
    )

    $secret = ConvertTo-SecureString -String $Password -AsPlainText -Force
    $ou_directories = $OUPath.Split(".").trim()
    $dc_distinguished = ("DC=", ($Domain.Split(".").trim() -join ",DC=") -join "")
    $ou_distinguished = ("OU=", ($ou_directories -join ",OU=") -join "")
    $full_path = "$ou_distinguished,$dc_distinguished"
    $ou_parents = $dc_distinguished
    $error_counter = 0
    [array]::reverse($ou_directories)

    if ($CSV) {
        $user_data = Import-Csv "bulk-add-adaccounts.csv" -Delimiter $CSVDelimiter
    }

    for ($i = 0; $i -lt $ou_directories.Count; $i++) {
        if ($i -gt 0) {
            $ou_parents = ("OU=", $ou_directories[$i-1], ",", $ou_parents -join "")
        }
        try {
            New-ADOrganizationalUnit -Name $ou_directories[$i] -Path $ou_parents -ProtectedFromAccidentalDeletion 0 -ErrorAction Stop
        }
        catch {
            $message = $_
            if ($message -inotmatch "already in use") {
                Write-Output ("[", $ou_directories[$i], "]: ", $_.Exception.Message -join "")
                $error_counter++
            }
        }
    }

    for ($i = 1; $i -le $Create; $i++) {
        try {
            $description = "Test Account (Remove for Production)"
            if ($CSV) {
                $given = $user_data.first_name | Get-Random
                $surname = $user_data.last_name | Get-Random
                $display = "$given $surname"
                $account = "$given$surname".replace("'", "").tolower()
                $upn = "$account@$Domain"
                New-ADUser -Name $display -GivenName $given -Surname $surname -DisplayName $display -SamAccountName $account -UserPrincipalName $upn -AccountPassword $secret -Path $full_path -Description $description -Enabled 1 -ChangePasswordAtLogon 0 -ErrorAction Stop

            } elseif ($Computer) {
                $given = ($Names, "_", ([string]($i)).padleft(($Create.count + 1), "0") -join "")
                New-ADComputer -Name $given -AccountPassword $secret -Path $full_path -Description $description -Enabled 1 -ChangePasswordAtLogon 1 -ErrorAction Stop

            } else {
                $given = ($Names, "_", ([string]($i)).padleft(($Create.count + 1), "0") -join "")
                New-ADUser -Name $given -AccountPassword $secret -Path $full_path -Description $description -Enabled 1 -ChangePasswordAtLogon 1 -ErrorAction Stop
            }
            # Offer to add users to their existing global group (with default from domainjoinprep script)
        }
        catch {
            if ($CSV) {
                Write-Output ("[$display]: ", $_.Exception.Message -join "")
            } else {
                Write-Output ("[$given]: ", $_.Exception.Message -join "")
            }
            Write-Output "`nAn error occured.`nIt is possible that faulty users were already created, please manually check.`nExiting script."
            return
        }
    }

    <#

    .SYNOPSIS
    Bulk create fictional user accounts for test data in your active directory.

    .DESCRIPTION

    Takes several optional arguments or sane defaults to create a bulk of randomized
    accounts to use in active directory test environments.
    CSV data can be used for creation. The provided CSV contains purely fictional data.

    .PARAMETER Domain

    Fully qualified domain name of the domain where this user shall be created

    .PARAMETER Names

    Only used when not reading from CSV. Creates users based on this string.

    .PARAMETER Password

    Change the password for all users.
    [Default]: "p@ssw0rd"

    .PARAMETER OUPath

    Change the pathing for the organizational unit structure of this bulk.
    Write from child to parent and separate with dots.
    [Default]: "OU_USR.OU_TEST"

    .PARAMETER Create

    The amount of accounts to be created.
    [Default]: 10

    .PARAMETER computer

    Create computer objects instead of users.

    .PARAMETER CSV

    Read data from CSV file specified. Path absolute or relative to script.
    The file MUST have a column labeled first_name and a column labeled last_name.
    If your CSV file does not use a comma as delimiter, use the corresponding parameter.

    .PARAMETER CSVDelimiter

    If your CSV file uses a non-standard delimiter use this in conjunction with -csv

    .EXAMPLE

    Add-Bulk-ADUsers -Domain contoso.com -Create 40 -OUPath "Test_Users.Accounting._NYC" -CSV

    .LINK

    https://github.com/MarianArlt/PoSh-ADDS-Tools

    #>