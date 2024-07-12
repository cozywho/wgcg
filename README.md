wgcg.sh script is reliant on Wireguard being configured & installed.
you can utilize wgsg (Wireguard Server Generator) to build out your server side.

wgcg.sh & ipspace.txt need to be in the same folder.

Modify the ipspace.txt file for your environment, keep same formatting.

Command should look like "sudo wgcg username1 username2 .... usernameN".
Example: sudo wgcg cozywho
Output will generate a correctly formatted client cert named cozywho.conf
