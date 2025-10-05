'use strict';

import * as uconfig from 'cli.uconfig';
import * as editor from 'cli.object-editor';

const tailscale_editor = {
	change_cb: uconfig.changed,

	named_args: {
		'auto-start': {
			help: 'Automatically start Tailscale on boot',
			default: false,
			args: {
				type: 'bool',
			}
		},

		'exit-node': {
			help: 'Advertise this device as an exit node',
			default: false,
			args: {
				type: 'bool',
			}
		},

		'announce-routes': {
			help: 'Announce LAN routes to Tailnet',
			default: false,
			args: {
				type: 'bool',
			}
		},
	}
};
uconfig.add_node('ucTailscale', editor.new(tailscale_editor));

const ucServices = {
	tailscale: {
		help: 'Configure Tailscale VPN',
		select_node: 'ucTailscale',
		select: function(ctx, argv) {
			return ctx.set(null, { edit: uconfig.lookup([ 'services', 'tailscale' ]) });
		},
	},
};
uconfig.add_node('ucServices', ucServices);

push(model.uconfig.services, 'tailscale');
