# DemoEnvironment
This is a demo environment with 1 DC, 1 member computer running Windows 11. I have commented out the domain join on the latest version since most scenarios I work with now is with cloud joined devices.

Recommend to use bastion host developer edition to connect to VMs. Since this is in preview and disabled I run the following commands in cloud shell after I have provisioned the lab environment:

az network vnet subnet create --resource-group <your resource-group> --vnet-name demo-vnet --name AzureBastionSubnet --address-prefix 10.0.1.0/27
az network public-ip create --resource-group <your resource-group> --name bastion-public-ip --sku Standard --location swedencentral
az network bastion create --resource-group <your resource-group> --name bastion-host --vnet-name demo-vnet --public-ip-address bastion-public-ip --location swedencentral --sku Developer


/Notes
To decompile a new json template run: az bicep build --file template.bicep