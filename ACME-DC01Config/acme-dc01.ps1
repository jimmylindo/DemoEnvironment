New-Item -Path c:\ -Name temp -Type Directory
#ladda hem användarlista
Invoke-WebRequest -Uri https://raw.githubusercontent.com/jimmylindo/DemoEnvironment/refs/heads/main/ACME-DC01Config/FirstLastEurope.csv -OutFile C:\temp\FirstLastEurope.csv -UseBasicParsing

#Skapa Share för användare
New-SmbShare -name resources -Path C:\temp -FullAccess "corp\Domain Users"

#Installera roller och OU struktur
        Add-WindowsFeature RSAT-ADDS,RSAT-DNS-Server
            New-ADOrganizationalUnit -Name "ACME" -ProtectedFromAccidentalDeletion $false
            New-ADOrganizationalUnit -Path "OU=ACME,DC=corp,DC=acme,DC=com" -Name "Users" -ProtectedFromAccidentalDeletion $false
            New-ADOrganizationalUnit -Path "OU=ACME,DC=corp,DC=acme,DC=com" -Name "Groups" -ProtectedFromAccidentalDeletion $false
            New-ADOrganizationalUnit -Path "OU=ACME,DC=corp,DC=acme,DC=com" -Name "ServiceAccounts" -ProtectedFromAccidentalDeletion $false
            New-ADOrganizationalUnit -Path "OU=ACME,DC=corp,DC=acme,DC=com" -Name "Computers" -ProtectedFromAccidentalDeletion $false
            New-ADOrganizationalUnit -Path "OU=ACME,DC=corp,DC=acme,DC=com" -Name "Servers" -ProtectedFromAccidentalDeletion $false
            New-ADOrganizationalUnit -Path "OU=ACME,DC=corp,DC=acme,DC=com" -Name "Contacts" -ProtectedFromAccidentalDeletion $false

#Skapa GPO för local admin på klienter
            $GPO = New-GPO -Name "Computer - Local administrator"
            $domain = Get-ADDomain

            Start-BitsTransfer -Source https://github.com/jimmylindo/M365Masterclass2022/raw/main/ACME-DC01Config/LocalGPO.zip -Destination C:\Temp
            Expand-Archive -Path "c:\temp\localgpo.zip" -DestinationPath C:\temp\localgpo
            Import-GPO -Path C:\temp\localgpo\JimmyTest -BackupId 45F24E2C-5826-4C62-9AF2-55E462B0774A -TargetGuid $GPO.Id -Domain $domain.Forest
            New-GPLink -Name $gpo.DisplayName -Target "OU=Computers,OU=ACME,DC=corp,DC=acme,DC=com" 

#Shapa användare


        $Names = Import-CSV C:\Temp\FirstLastEurope.csv | Select-Object -First 50
        $OU = "OU=Users,OU=ACME,DC=corp,DC=acme,DC=com"
        $UPNSuffix = (Get-ADDomain).DnsRoot

        #Import required module ActiveDirectory
        try{
            Import-Module ActiveDirectory -ErrorAction Stop
        }
        catch{
            throw "Module GroupPolicy not Installed"
        }

        foreach ($name in $names) {
            
            #Generate username and check for duplicates
            $firstname = $name.firstname
            $lastname = $name.lastname 

            $username = $name.firstname.Substring(0,3).tolower() + $name.lastname.Substring(0,3).tolower()
            $exit = 0
            $count = 1
            do
            { 
                try { 
                    $userexists = Get-AdUser -Identity $username
                    $username = $firstname.Substring(0,3).tolower() + $lastname.Substring(0,3).tolower() + $count++
                }
                catch {
                    $exit = 1
                }
            }
            while ($exit -eq 0)

            #Set Displayname and UserPrincipalNBame
            $displayname = "$firstname $lastname ($username)"
            if ($firstname -eq "alp") {
                $upn = "{0}.{1}@{2}" -f $firstname,$lastname,(Get-ADForest).name
            } else {
                $upn = "$username@$upnsuffix"
            }
            #Create the user
            Write-Host "Creating user $username in $ou"
            New-ADUser –Name $displayname –DisplayName $displayname `
                 –SamAccountName $username -UserPrincipalName $upn `
                 -GivenName $firstname -Surname $lastname -description "Test User" `
                 -Path $ou –Enabled $true `
                 -PasswordNotRequired $true

        }
