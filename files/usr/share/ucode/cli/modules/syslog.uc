'use strict';

import { popen } from 'fs';

function syslog_read(ctx, argv, named) {
	let p = popen('logread');
	if (!p)
		return ctx.error('ERROR', 'Failed to run logread');

	let line;
	while ((line = p.read('line')) != null)
		printf('%s', line);

	p.close();

	return ctx.ok();
}

const Root = {
	syslog: {
		help: 'Show system log',
		call: syslog_read,
	},
};
model.add_node('Root', Root);
