'use strict';

import * as uconfig from 'cli.uconfig';
import * as editor from 'cli.object-editor';

const log_editor = {
	change_cb: uconfig.changed,

	named_args: {
		host: {
			help: 'Remote syslog server address',
			args: {
				type: 'host',
			}
		},

		port: {
			help: 'Remote syslog server port',
			args: {
				type: 'int',
				min: 100,
				max: 65535,
			}
		},

		proto: {
			help: 'Protocol for remote syslog',
			default: 'udp',
			args: {
				type: 'enum',
				value: [ 'tcp', 'udp' ],
			}
		},

		size: {
			help: 'Log buffer size in KiB',
			default: 1000,
			args: {
				type: 'int',
				min: 32,
			}
		},

		priority: {
			help: 'Log priority filter (0-7)',
			default: 7,
			args: {
				type: 'int',
				min: 0,
				max: 7,
			}
		},
	}
};
uconfig.add_node('ucLog', editor.new(log_editor));

const ucServices = {
	log: {
		help: 'Configure remote syslog',
		select_node: 'ucLog',
		select: function(ctx, argv) {
			return ctx.set(null, { edit: uconfig.lookup([ 'services', 'log' ]) });
		},
	},
};
uconfig.add_node('ucServices', ucServices);

push(model.uconfig.services, 'log');
