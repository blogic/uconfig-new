'use strict';

import * as uconfig from 'cli.uconfig';
import * as editor from 'cli.object-editor';

const ieee8021x_editor = {
	change_cb: uconfig.changed,

	named_args: {
		'radius-server': {
			help: 'RADIUS server name from definitions',
			args: {
				type: 'enum',
				value: function() {
					return sort(keys(uconfig.lookup([ 'definitions', 'radius-servers' ]) || {}));
				},
			}
		},
	}
};
uconfig.add_node('ucIEEE8021X', editor.new(ieee8021x_editor));

const ucServices = {
	ieee8021x: {
		help: 'Configure wired 802.1X authentication',
		select_node: 'ucIEEE8021X',
		select: function(ctx, argv) {
			return ctx.set(null, { edit: uconfig.lookup([ 'services', 'ieee8021x' ]) });
		},
	},
};
uconfig.add_node('ucServices', ucServices);

push(model.uconfig.services, 'ieee8021x');
