'use strict';

let claims = {};

export function claim(service, port, proto, interfaces) {
	let key = `${port}/${proto}`;

	claims[key] ??= [];

	let iface_names = map(interfaces, (i) => i.name);

	for (let claim in claims[key]) {
		let overlapping = filter(iface_names, (n) => index(claim.interfaces, n) >= 0);
		if (!length(overlapping))
			continue;

		return { service: claim.service, interfaces: overlapping };
	}

	push(claims[key], { service, interfaces: iface_names });

	return null;
};

export function init() {
	claims = {};
};
