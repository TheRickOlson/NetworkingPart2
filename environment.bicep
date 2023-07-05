// Environment:
// - One VNET
// -- One Subnet

// New-AzResourceGroupDeployment -Name "deploy" -ResourceGroup "RSG" -TemplateFile ./environment.bicep
param location string = 'westus2'
param clientName string = 'vm1'
param serverName string = 'server1'

// This should be your IP - this is used to restrict external TCP/3389 to just your machine
// Easiest way to get this if you don't know it is to search "what's my IP" on Bing
param allowedIP string = '1.2.3.4'   

// This username/password will be used to log into the test VMs
// It is never recommended that you store passwords in code like this
// Don't be like me :)
param user string = 'testuser1'
param pass string = 'TheStr0nge5tPWD!'

resource vnet 'Microsoft.Network/virtualNetworks@2022-11-01' = {
  name: 'VNET-TEST'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.10.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'SUBNET-VMs'
        properties: {
          addressPrefix: '10.10.10.0/24'
        }
      }
    ]
  }
  
  resource vmsubnet 'subnets' existing = {
    name: 'SUBNET-VMs'
  }
}

resource PIP_client 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: 'pip-${clientName}'
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
  sku: {
    name: 'Basic'
  }
}

resource PIP_server 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: 'pip-${serverName}'
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
  sku: {
    name: 'Basic'
  }
}

resource NSG_AllowRDP 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: 'nsg-allowrdp'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowRDP'
        properties: {
          protocol: 'Tcp'
          sourceAddressPrefix: allowedIP
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowPing'
        properties: {
          protocol: 'ICMP'
          sourceAddressPrefix: '10.10.10.0/24'
          sourcePortRange: '*'
          destinationAddressPrefix: '10.10.10.0/24'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHTTP'
        properties: {
          protocol: 'Tcp'
          sourceAddressPrefix: '10.10.10.0/24'
          sourcePortRange: '*'
          destinationAddressPrefix: '10.10.10.0/24'
          destinationPortRange: '80'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource NIC_client 'Microsoft.Network/networkInterfaces@2022-11-01' = {
  name: '${clientName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: vnet::vmsubnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: PIP_client.id
          }
        }
      }
    ]

    networkSecurityGroup: {
      id: NSG_AllowRDP.id
    }
  }
}

resource NIC_server 'Microsoft.Network/networkInterfaces@2022-11-01' = {
  name: '${serverName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: vnet::vmsubnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: PIP_server.id
          }
        }
      }
    ]

    networkSecurityGroup: {
      id: NSG_AllowRDP.id
    }
  }
}

resource clientvm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: clientName
  location: location
  dependsOn: [
    NIC_client
  ]
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v5'
    }

    osProfile: {
      computerName: clientName
      adminUsername: user
      adminPassword: pass
    }

    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'Windows-11'
        sku: 'win11-21h2-pro'
        version: 'latest'
      }

      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: NIC_client.id
        }
      ]
    }
  }
}

resource servervm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: serverName
  location: location
  dependsOn: [
    NIC_server
  ]
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v5'
    }

    osProfile: {
      computerName: serverName
      adminUsername: user
      adminPassword: pass
    }

    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter'
        version: 'latest'
      }

      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: NIC_server.id
        }
      ]
    }
  }
}
