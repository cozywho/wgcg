
--------------------  
wgcg is a server side client generator that will install and configure wireguard. i use this on fedora based distros.  
Peep the install.sh for the firewalld (firewall-cmd) rules, and treak if u need to.
ipspace.txt's allowed IPs will most likely be x.x.x.x/x(wg0-subnet),x.x.x.x/x(lan-subnet).
Endpoint is public ip or domain name.

--------------------

WGCG:  
Command should look like "sudo wgcg username1 username2 .... usernameN".  
Example: sudo wgcg cozywho  

Output will generate a correctly formatted client cert named cozywho.conf in the /etc/wireguard/certs folder.

TODO:  
--- need to make a copy of the *.conf files and put them in user/Documents/ mkdir wg-certs or sumthin.  
--- add a revocation funtion. "wgcg --remove user". should probably do a wgcg --add user instead of just wgcg certname if i do this.
