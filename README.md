wgcg.sh is a server side client generator & is reliant on Wireguard being installed & configured.

You can utilize wgsg (Wireguard Server Generator) to build out your server side (WIP).

Command should look like "sudo wgcg username1 username2 .... usernameN".

Example: sudo wgcg cozywho

Output will generate a correctly formatted client cert named cozywho.conf in the /etc/wireguard/certs folder.

--- need to fix the install portion and correctly place ipspace.txt file.

--- need to make a copy of the *.conf files and put them in user/Documents/ mkdir wg-certs or sumthin
