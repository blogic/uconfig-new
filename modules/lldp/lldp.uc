{%
	let management = services.lookup_interfaces("lldp-mgmt");
	let interfaces = [ ...management, ... services.lookup_interfaces("lldp") ];
	let enable = length(management) && length(interfaces);
	services.set_enabled("ulldpd", !!enable);
	if (!enable)
		return;
%}

# Configure LLDP
{% if (lldp.system_name): %}
set lldp.@global[0].name={{ s(lldp.system_name) }}
{% endif %}
{% if (lldp.system_description): %}
set lldp.@global[0].description={{ s(lldp.system_description) }}
{% endif %}
{% for (let interface in interfaces):
	for (let port in ethernet.lookup_by_interface_spec(interface)): %}
add_list lldp.@global[0].device={{ s(port) }}
{% 	endfor
endfor %}
set lldp.@global[0].mgmt_iface={{ s(ethernet.lookup_by_interface_spec(management[0])[0]) }}
