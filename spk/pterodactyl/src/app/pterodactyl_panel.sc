[pterodactyl_panel]
title="Pterodactyl Panel Web"
desc="Web panel interface"
port_forward="yes"
dst.ports="38080/tcp"

[pterodactyl_wings]
title="Pterodactyl Wings API"
desc="Wings daemon API (HTTPS)"
port_forward="yes"
dst.ports="8443/tcp"

[pterodactyl_sftp]
title="Pterodactyl SFTP"
desc="Wings SFTP server for file transfers"
port_forward="yes"
dst.ports="2022/tcp"
