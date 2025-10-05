'use strict';

import * as uconfig from 'cli.uconfig';
import * as editor from 'cli.object-editor';

const ethernet_editor = {
	change_cb: uconfig.changed,

	named_args: {
		'select-ports': {
			help: 'Physical ports to configure (patterns like LAN*, WAN*, *)',
			multiple: true,
			required: true,
			args: {
				type: 'string',
			}
		},

		speed: {
			help: 'Forced link speed in Mbps',
			set: (ctx, val) => {
				ctx.data.edit['speed'] = +val;
			},
			args: {
				type: 'enum',
				value: [ '10', '100', '1000', '2500', '5000', '10000' ],
			}
		},

		duplex: {
			help: 'Forced duplex mode',
			args: {
				type: 'enum',
				value: [ 'half', 'full' ],
			}
		},
	}
};

const ethernet_edit_create_destroy = {
	change_cb: uconfig.changed,
	types: {},
};

const ucEthernet = {};
editor.new(ethernet_editor, ucEthernet);
editor.edit_create_destroy(ethernet_edit_create_destroy, ucEthernet);
uconfig.add_node('ucEthernet', ucEthernet);

const ucEdit = {
	ethernet: {
		help: 'Configure ethernet port settings',

		args: [
			{
				name: 'index',
				type: 'int',
				min: 1,
				required: true,
			}
		],

		select_node: 'ucEthernet',

		select: function(ctx, argv) {
			let idx = +argv[0] - 1;
			let ethernet = uconfig.lookup([ 'ethernet' ]) || [];

			if (idx < 0 || idx >= length(ethernet)) {
				warn(`Error: Invalid ethernet index\n`);
				return;
			}

			return ctx.set(`ethernet ${argv[0]}`, {
				edit: ethernet[idx],
			});
		},
	},
};
uconfig.add_node('ucEdit', ucEdit);
