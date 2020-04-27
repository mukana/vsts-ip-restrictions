# VSTS IP Restrictions

This modules makes it possible to add IP restrictions to an Azure App Service.
There is an option for adding custom addresses and there is an option for adding the IP Address of the build server.

## IP Address format
IP addresses can be specified individually (e.g. 1.2.3.4) or as ranges using CIDR syntax (e.g. 10.0.0.0/24).  Comments can also be added to each IP address by separating the comment from the IP address with a space.  The comments are ignored when deploying to Azure, but remain in the VSTS task for reference.  An example is shown below.

[IP addresses input dialog]
10.0.0.0/24 Production subnet
10.2.0.1
192.168.0.1 External server
