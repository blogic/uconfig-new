{%
	// Helper functions
	function has_mdns_service() {
		return services.is_present("avahi-daemon");
	}

	function get_mdns_interfaces() {
		let interfaces = services.lookup_interfaces("mdns");
		let fingerprint = services.lookup_interfaces("fingerprint");

		return uniq([ ...interfaces, ...fingerprint ]);
	}

	// Configuration generation functions
	function generate_hostname_file(mdns) {
		let hosts = {};

		for (let hostname in mdns?.additional_hostnames || [])
			hosts[hostname + ".local"] = {
				hostname: hostname + ".local"
			};

		if (length(hosts))
			fs.writefile('/etc/umdns/uconfig.json', hosts);
	}

	function generate_mdns_firewall_rules(interfaces) {
		if (!length(interfaces))
			return '';

		let output = [];

		uci_comment(output, '### generate mdns firewall rules');

		for (let interface in interfaces) {
			let name = interface.name;

			uci_section(output, 'firewall rule');
			uci_set_string(output, 'firewall.@rule[-1].name', `Allow-mdns-${name}`);
			uci_set_string(output, 'firewall.@rule[-1].src', name);
			uci_set_string(output, 'firewall.@rule[-1].dest_port', 5353);
			uci_set_string(output, 'firewall.@rule[-1].proto', 'udp');
			uci_set_string(output, 'firewall.@rule[-1].target', 'ACCEPT');
		}

		return uci_output(output);
	}

	// Main logic
	if (!has_mdns_service())
		return;

	let interfaces = get_mdns_interfaces();
	let enable = length(interfaces) > 0;

	services.set_enabled("avahi-daemon", enable ? 'restart' : false);

	if (!enable)
		return;

	generate_hostname_file(mdns);
%}

## Configure MDNS
{{ generate_mdns_firewall_rules(interfaces) }}
