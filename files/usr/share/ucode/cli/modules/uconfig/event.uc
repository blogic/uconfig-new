'use strict';

import * as ubus from 'ubus';
import * as uconfig from 'cli.uconfig';

const ucEventLog = {
	event: {
		help: 'Show uconfig event log',
		call: function(ctx, argv) {
			let log = ubus.call('event', 'log');

			printf('%.J\n', log.log);

			return ctx.ok('Done');
		}
	},
};
model.add_node('ucEventLog', ucEventLog);

const uConfig = {
	log: {
		help: 'Look at system events and logs',
		select_node: 'ucEventLog',
	},
};
model.add_node('uConfig', uConfig);
