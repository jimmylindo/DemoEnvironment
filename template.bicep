@description('This deploys the resources to Region North Europe. We use the resources in this location because bastion host in dev mode')
param location string = 'northeurope'

param VNET_NSG_Name string = 'adds-subnet-vnet-nsg'

@description('Virtual network address range.')
param virtualNetworkAddressRange string = '10.0.0.0/16'

param VNET_Name string = 'demo-vnet'
@description('Subnet name.')
param subnetName string = 'adds-subnet'

@description('Subnet IP range.')
param subnetRange string = '10.0.0.0/24'

@description('UserName')
param adminUsername string = 'sysadmin'

@description('The password for the administrator account of the new VM and domain')
@secure()
param adminPassword string = 'Passw0rd1234!'

@description('Virtual Machine Domain Controller')
param VM_acme_dc01_name string = 'acme-dc01'

param networkInterfaces_acme_dc01 string = 'acme-dc01-nic'

//param schedules_shutdown_computevm_acme_dc01_name string = 'Shutdown-dc01'

@description('Private IP address of Domain controller.')
param VM_acme_dc01_privateIP string = '10.0.0.4'

@description('The location of resources such as templates and DSC modules that the script is dependent')
param assetLocation_CreateADForest string = 'https://raw.githubusercontent.com/jimmylindo/DemoEnvironment/refs/heads/main/DSC/'

@description('The location of resources such as templates and DSC modules that the script is dependent')
param assetLocation_dc01 string = 'https://raw.githubusercontent.com/jimmylindo/DemoEnvironment/refs/heads/main/ACME-DC01Config/'

@description('The FQDN of the Active Directory Domain to be created')
param domainName string = 'CORP.ACME.COM'


//param schedules_shutdown_computevm_acme_dc01_name string = 'shutdown-computevm-acme-dc01'
//param schedules_shutdown_computevm_demo_cl01_name string = 'shutdown-computevm-demo-cl01'

resource vnet_nsg_name_resource 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: VNET_NSG_Name
  location: location
  properties: {
    securityRules: []
  }

}

resource VNET_Name_resource 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: VNET_Name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkAddressRange
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetRange
          networkSecurityGroup: {
            id: vnet_nsg_name_resource.id
          }
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
    ]
    virtualNetworkPeerings: []
    enableDdosProtection: false
  }
}

resource networkInterface_dc01_resource 'Microsoft.Network/networkInterfaces@2024-03-01' = {
  name: networkInterfaces_acme_dc01
  location: location
  dependsOn: [
    VNET_Name_resource
  ]
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: VM_acme_dc01_privateIP
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', VNET_Name, subnetName)
          }
        }
      }
    ]    
  }
}

resource VM_acme_dc01_Resource 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: VM_acme_dc01_name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2ms'
    }
    osProfile: {
      computerName: VM_acme_dc01_name
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2025-datacenter-azure-edition'
        version: 'latest'
        //publisher: 'MicrosoftWindowsServer'
        //offer: 'WindowsServer'
        //sku: '2025-Datacenter-smalldisk'
        //version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface_dc01_resource.id
        }
      ]
    }
    licenseType: 'Windows_Server'
    securityProfile: {
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
      securityType: 'TrustedLaunch'
    }
  }
}

/*resource schedules_shutdown_computevm_acme_dc01_name_resource 'microsoft.devtestlab/schedules@2018-09-15' = {
  name: schedules_shutdown_computevm_acme_dc01_name
  location: 'northeurope'
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: '1900'
    }
    timeZoneId: 'UTC'
    notificationSettings: {
      status: 'Enabled'
      timeInMinutes: 30
      emailRecipient: 'jimmy@cloudtechnu.onmicrosoft.com'
      notificationLocale: 'en'
    }
    targetResourceId: VM_acme_dc01_Resource.id
  }
}
*/

resource DSC_ADDS_Extention_to_AMCE_DC01 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: VM_acme_dc01_Resource
  name: 'CreateADForest'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.79'
    autoUpgradeMinorVersion: true
    settings: {
      ModulesUrl: '${assetLocation_CreateADForest}CreateADPDC.zip'
      ConfigurationFunction: 'CreateADPDC.ps1\\CreateADPDC'
      Properties: {
        DomainName: domainName
        AdminCreds: {
          UserName: adminUsername
          Password: 'PrivateSettingsRef:AdminPassword'
        }
      }
    }
    protectedSettings: {
      Items: {
        AdminPassword: adminPassword
      }
    } 
  }
}

module Update_VNET_DNS 'nestedtemplates/vnet-with-dns-server.bicep' = {
  name: 'UpdateVNetDNS'
  params: {
    location: location
    DNSServerAddress: [
      VM_acme_dc01_privateIP
    ]
    networkSecurityGroupName: VNET_NSG_Name
    subnetName: subnetName
    subnetRange: subnetRange
    virtualNetworkAddressRange: virtualNetworkAddressRange
    virtualNetworkName: VNET_Name
  }
  dependsOn: [
    DSC_ADDS_Extention_to_AMCE_DC01
  ]
}

resource ACME_DC01_CustomScript 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  name: 'ACME-DC01/CustomScript'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.4'
    settings: {
      fileUris: [
        '${assetLocation_dc01}acme-dc01.ps1'
      ]
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File acme-dc01.ps1'
    }
  }
  dependsOn: [
    DSC_ADDS_Extention_to_AMCE_DC01
  ]
}

module acme_cl01 './nestedtemplates/acme-cl01.bicep' = {
  name: 'acme-cl01'
  params: {
    location: location
    adminUsername: adminUsername
    adminPassword: adminPassword
    domainName: domainName
    subnetName: subnetName
    virtualNetworkName: VNET_Name
  }
  dependsOn: [
    Update_VNET_DNS
  ]
}

/*

resource schedules_shutdown_computevm_acme_dc01_name_resource 'microsoft.devtestlab/schedules@2018-09-15' = {
  name: schedules_shutdown_computevm_acme_dc01_name
  location: 'northeurope'
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: '1900'
    }
    timeZoneId: 'UTC'
    notificationSettings: {
      status: 'Enabled'
      timeInMinutes: 30
      emailRecipient: 'jimmy@cloudtechnu.onmicrosoft.com'
      notificationLocale: 'en'
    }
    targetResourceId: virtualMachines_acme_dc01_name_resource.id
  }
}

resource schedules_shutdown_computevm_demo_cl01_name_resource 'microsoft.devtestlab/schedules@2018-09-15' = {
  name: schedules_shutdown_computevm_demo_cl01_name
  location: 'northeurope'
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: '1900'
    }
    timeZoneId: 'UTC'
    notificationSettings: {
      status: 'Enabled'
      timeInMinutes: 30
      emailRecipient: 'jimmy@cloudtechnu.onmicrosoft.com'
      notificationLocale: 'en'
    }
    targetResourceId: virtualMachines_demo_cl01_name_resource.id
  }
}

resource networkInterfaces_acme_dc01688_name_resource 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: networkInterfaces_acme_dc01688_name
  location: 'northeurope'
  kind: 'Regular'
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        id: '${networkInterfaces_acme_dc01688_name_resource.id}/ipConfigurations/ipconfig1'
        type: 'Microsoft.Network/networkInterfaces/ipConfigurations'
        properties: {
          privateIPAddress: '10.0.0.5'
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: virtualNetworks_demo_cl01_vnet_name_default.id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    dnsSettings: {
      dnsServers: []
    }
    enableAcceleratedNetworking: false
    enableIPForwarding: false
    disableTcpStateTracking: false
    nicType: 'Standard'
    auxiliaryMode: 'None'
    auxiliarySku: 'None'
  }
}

resource virtualNetworks_demo_cl01_vnet_name_default 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = {
  name: '${virtualNetworks_demo_cl01_vnet_name}/default'
  properties: {
    addressPrefix: '10.0.0.0/24'
    delegations: []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    virtualNetworks_demo_cl01_vnet_name_resource
  ]
}

resource networkInterfaces_demo_cl01374_name_resource 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: networkInterfaces_demo_cl01374_name
  location: 'northeurope'
  kind: 'Regular'
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        id: '${networkInterfaces_demo_cl01374_name_resource.id}/ipConfigurations/ipconfig1'
        type: 'Microsoft.Network/networkInterfaces/ipConfigurations'
        properties: {
          privateIPAddress: '10.0.0.4'
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: virtualNetworks_demo_cl01_vnet_name_default.id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    dnsSettings: {
      dnsServers: []
    }
    enableAcceleratedNetworking: true
    enableIPForwarding: false
    disableTcpStateTracking: false
    networkSecurityGroup: {
      id: networkSecurityGroups_demo_cl01_nsg_name_resource.id
    }
    nicType: 'Standard'
    auxiliaryMode: 'None'
    auxiliarySku: 'None'
  }
}
*/
