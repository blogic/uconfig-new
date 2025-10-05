'use strict';

import * as uconfig from 'cli.uconfig';
import * as editor from 'cli.object-editor';

const lldp_editor = {
	change_cb: uconfig.changed,

	named_args: {
		hostname: {
			help: 'Hostname announced via LLDP',
			default: 'OpenWrt',
			args: {
				type: 'string',
			}
		},

		description: {
			help: 'Description announced via LLDP',
			default: 'OpenWrt',
			args: {
				type: 'string',
			}
		},

		location: {
			help: 'Location announced via LLDP',
			default: 'LAN',
			args: {
				type: 'string',
			}
		},
	}
};
uconfig.add_node('ucLLDP', editor.new(lldp_editor));

const ucServices = {
	lldp: {
		help: 'Configure LLDP announcements',
		select_node: 'ucLLDP',
		select: function(ctx, argv) {
			return ctx.set(null, { edit: uconfig.lookup([ 'services', 'lldp' ]) });
		},
	},
};
uconfig.add_node('ucServices', ucServices);

push(model.uconfig.services, 'lldp');
