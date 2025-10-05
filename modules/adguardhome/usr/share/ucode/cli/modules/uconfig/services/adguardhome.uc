'use strict';

import * as uconfig from 'cli.uconfig';
import * as editor from 'cli.object-editor';

const adguardhome_editor = {
	change_cb: uconfig.changed,

	named_args: {
		'webui-port': {
			help: 'WebUI port',
			default: 3000,
			args: {
				type: 'int',
				min: 100,
				max: 65535,
			}
		},

		'dns-intercept': {
			help: 'Intercept all DNS traffic on enabled interfaces',
			args: {
				type: 'bool',
			}
		},

		servers: {
			help: 'Upstream DNS servers',
			multiple: true,
			args: {
				type: 'ipv4',
			}
		},

		htpasswd: {
			help: 'Password hash for admin login (generated via htpasswd -B)',
			args: {
				type: 'string',
			}
		},
	}
};
uconfig.add_node('ucAdGuardHome', editor.new(adguardhome_editor));

const ucServices = {
	adguardhome: {
		help: 'Configure AdGuard Home DNS filtering',
		select_node: 'ucAdGuardHome',
		select: function(ctx, argv) {
			return ctx.set(null, { edit: uconfig.lookup([ 'services', 'adguardhome' ]) });
		},
	},
};
uconfig.add_node('ucServices', ucServices);

push(model.uconfig.services, 'adguardhome');
