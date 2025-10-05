'use strict';

import { popen } from 'fs';

function dmesg_read(ctx, argv, named) {
	let p = popen('dmesg');
	if (!p)
		return ctx.error('ERROR', 'Failed to run dmesg');

	let line;
	while ((line = p.read('line')) != null)
		printf('%s', line);

	p.close();

	return ctx.ok();
}

const Root = {
	dmesg: {
		help: 'Show kernel log',
		call: dmesg_read,
	},
};
model.add_node('Root', Root);
