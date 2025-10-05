'use strict';

import * as ubus from 'ubus';

function fingerprint_show(ctx, argv, named) {
	let result = ubus.call('fingerprint', 'fingerprint');
	if (!result)
		return ctx.error('UBUS_ERROR', 'fingerprint service not available');

	let macs = sort(keys(result));

	for (let mac in macs) {
		let info = result[mac];
		if (!length(keys(info)))
			continue;

		printf('%s\n', mac);
		if (info.device_name)
			printf('  name:   %s\n', info.device_name);
		if (info.vendor)
			printf('  vendor: %s\n', info.vendor);
		if (info.device)
			printf('  device: %s\n', info.device);
		if (info.class)
			printf('  class:  %s\n', info.class);
	}

	return ctx.ok();
}

const Root = {
	fingerprint: {
		help: 'Show device fingerprints',
		call: fingerprint_show,
	},
};
model.add_node('Root', Root);
