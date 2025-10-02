
--------------------  
wgcg is a server side client generator that will install and configure wireguard on interface name wg0. 
--------------------
Assumed NIC is ens18, edit the install.sh to your liking before you run it.  
The PostUp and PostDown stuff are your firewall rules, just replicate based on your env.


WGCG:  
Command should look like "sudo wgcg username1 username2 .... usernameN".  
Example: sudo wgcg cozywho  

Output will generate a correctly formatted client cert named cozywho.conf in the /etc/wireguard/certs folder.

TODO:  
--- need to make a copy of the *.conf files and put them in user/Documents/ mkdir wg-certs or sumthin.  
--- add a revocation funtion. "wgcg --remove user". should probably do a wgcg --add user instead of just wgcg certname if i do this.
