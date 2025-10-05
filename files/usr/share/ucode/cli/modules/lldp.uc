'use strict';

import { popen } from 'fs';

function lldp_show(ctx, argv, named) {
	let p = popen('lldpcli show neigh');
	if (!p)
		return ctx.error('ERROR', 'Failed to run lldpcli');

	let line;
	while ((line = p.read('line')) != null)
		printf('%s', line);

	p.close();

	return ctx.ok();
}

const Root = {
	lldp: {
		help: 'Show LLDP neighbours',
		call: lldp_show,
	},
};
model.add_node('Root', Root);
