'use strict';

import * as uconfig from 'cli.uconfig';
import * as editor from 'cli.object-editor';

const mdns_editor = {
	change_cb: uconfig.changed,

	named_args: {
		'additional-hostnames': {
			help: 'Additional hostnames to announce via mDNS',
			multiple: true,
			args: {
				type: 'string',
			}
		},
	}
};
uconfig.add_node('ucMDNS', editor.new(mdns_editor));

const ucServices = {
	mdns: {
		help: 'Configure mDNS announcements',
		select_node: 'ucMDNS',
		select: function(ctx, argv) {
			return ctx.set(null, { edit: uconfig.lookup([ 'services', 'mdns' ]) });
		},
	},
};
uconfig.add_node('ucServices', ucServices);

push(model.uconfig.services, 'mdns');
