[pteropanel]
title="PteroPanel Web"
desc="Web panel"
port_forward="yes"
dst.ports="{{wizard_http_port}}/tcp"

[pteropanel_wings]
title="PteroPanel Wings"
desc="Daemon API"
port_forward="yes"
dst.ports="8443/tcp"
