param domainName string

@description('The FQDN of the AD domain')
param domainToJoin string = 'corp.acme.com'


@description('Organizational Unit path in which the nodes and cluster will be present.')
param ouPath string = 'OU=Computers; OU=ACME; DC=corp; DC=acme; DC=com'

@description('Set of bit flags that define the join options. Default value of 3 is a combination of NETSETUP_JOIN_DOMAIN (0x00000001) & NETSETUP_ACCT_CREATE (0x00000002) i.e. will join the domain and create the account on the domain. For more information see https://msdn.microsoft.com/en-us/library/aa392154(v=vs.85).aspx')
param domainJoinOptions int = 3

@description('The name of the administrator of the new VM.')
param adminUsername string

@description('The password for the administrator account of the new VM.')
@secure()
param adminPassword string

@description('Subnet name.')
param subnetName string

@description('Virtual network name.')
param virtualNetworkName string

@description('Location for all resources.')
param location string

var computer_ACME_CL01 = 'acme-cl01'

resource acme_cl01_nic 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: '${computer_ACME_CL01}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
          }
        }
      }
    ]
  }
}

resource acme_cl01_vm 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: computer_ACME_CL01
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2ms'
    }
    osProfile: {
      computerName: computer_ACME_CL01
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: acme_cl01_nic.id
        }
      ]
    }
    storageProfile: {
      imageReference: {
        publisher: 'microsoftwindowsdesktop'
        offer: 'windows-11'
        sku: 'win11-24h2-entn'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        diskSizeGB: 127
      }
      
    }
    securityProfile: {
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
      securityType: 'TrustedLaunch'
    }
  }
}
