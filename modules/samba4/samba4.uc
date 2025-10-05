{%
	function generate_samba4_firewall_rules(interfaces) {
		if (!length(interfaces))
			return '';

		let output = [];

		uci_comment(output, '### configure samba4 firewall rules');

		for (let interface in interfaces) {
			let name = interface.name;

			uci_section(output, 'firewall rule');
			uci_set_string(output, 'firewall.@rule[-1].name', `Allow-samba4-netbios-${name}`);
			uci_set_string(output, 'firewall.@rule[-1].src', name);
			uci_set_string(output, 'firewall.@rule[-1].dest_port', '139');
			uci_set_string(output, 'firewall.@rule[-1].proto', 'tcp');
			uci_set_string(output, 'firewall.@rule[-1].target', 'ACCEPT');

			uci_section(output, 'firewall rule');
			uci_set_string(output, 'firewall.@rule[-1].name', `Allow-samba4-smb-${name}`);
			uci_set_string(output, 'firewall.@rule[-1].src', name);
			uci_set_string(output, 'firewall.@rule[-1].dest_port', '445');
			uci_set_string(output, 'firewall.@rule[-1].proto', 'tcp');
			uci_set_string(output, 'firewall.@rule[-1].target', 'ACCEPT');
		}

		return uci_output(output);
	}

	// Main logic
	let interfaces = services.lookup_interfaces("samba4");
	let enable = length(interfaces) > 0;

	services.set_enabled("samba4", enable);

	if (!enable)
		return;
%}

## Configure Samba4 firewall rules
{{ generate_samba4_firewall_rules(interfaces) }}
