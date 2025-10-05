'use strict';

import * as uconfig from 'cli.uconfig';
import * as editor from "cli.object-editor";
import * as wiphy from 'uconfig.wiphy';

const radio_editor = {
	change_cb: uconfig.changed,

	named_args: {
		'channel-mode': {
			help: 'Define the ideal channel mode that the radio shall use.',
			default: function(ctx)	{
				return ctx.data.default_mode;
			},
			required: true,
			args: {
				type: 'enum',
				value: function(ctx) {
					return ctx.data.channel_mode;
				}
			}
		},

		'channel-width': {
			help: 'The channel width that the radio shall use. ',
			default: function(ctx) {
				return ctx.data.default_width;
			},
			set: (ctx, val) => {
				ctx.data.edit['channel-width'] = +val;
			},
			required: true,
			args: {
				type: 'enum',
				value: function(ctx) {
					return ctx.data.channel_width;
				}
			}
		},

		'channel': {
			help: 'Specifies the wireless channel to use.',
			default: 'auto',
			required: true,
			set: (ctx, val) => {
				ctx.data.edit['channel'] = val == 'auto' ? 'auto' : +val;
			},
			args: {
				type: 'enum',
				value: function(ctx) {
					let channels = ['auto'];
					for (let c in ctx.data.channels || [])
						push(channels, '' + c.channel);
					return channels;
				}
			}
		},

		'allow-dfs': {
			help: 'This property defines whether a radio may use DFS channels.',
			default: true,
			available: function(ctx) {
				return ctx.data.allow_dfs;
			},
			args: {
				type: 'bool',
			}
		},

		'maximum-clients': {
			help: 'Set the maximum number of clients that may connect to this radio. This value is accumulative for all attached VAP interfaces.',
			args: {
				type: 'int',
			}
		},

		'he-multiple-bssid': {
			help: 'Enabling this option will make the PHY broadcast its BSSs using the multiple BSSID beacon IE.',
			available: function(ctx) {
				return ('HE' in ctx.data.channel_mode);
			},
			args: {
				type: 'bool',
			}
		},

		'tx-power': {
			help: 'Transmission power in dBm',
			args: {
				type: 'int',
				min: 0,
				max: function(ctx) {
					return ctx.data.max_tx_power || 30;
				},
			}
		},

		'legacy-rates': {
			help: 'Allow legacy 802.11b data rates',
			default: false,
			args: {
				type: 'bool',
			}
		},

		'require-mode': {
			help: 'Reject stations that do not fulfil this HT mode',
			args: {
				type: 'enum',
				value: [ 'HT', 'VHT', 'HE' ],
			}
		},

		'valid-channels': {
			help: 'List of valid channels for ACS',
			multiple: true,
			add: (ctx, val) => {
				let channels = ctx.data.edit['valid-channels'] ??= [];
				push(channels, +val);
			},
			remove: (ctx, val) => {
				let channels = ctx.data.edit['valid-channels'];
				if (!channels)
					return;
				let idx = index(channels, +val);
				if (idx >= 0)
					splice(channels, idx, 1);
				if (!length(channels))
					delete ctx.data.edit['valid-channels'];
			},
			set: (ctx, val) => {
				if (val == null)
					delete ctx.data.edit['valid-channels'];
				else
					ctx.data.edit['valid-channels'] = map(val, v => +v);
			},
			args: {
				type: 'enum',
				value: function(ctx) {
					let channels = [];
					for (let c in ctx.data.channels || [])
						push(channels, '' + c.channel);
					return channels;
				}
			}
		},
	}
};

const rate_values = [ '0', '1000', '2000', '5500', '6000', '9000', '11000', '12000', '18000', '24000', '36000', '48000', '54000' ];

const rates_editor = {
	change_cb: uconfig.changed,

	named_args: {
		'beacon': {
			help: 'Beacon rate in kbps (e.g. 6000 = 6 Mbps)',
			default: 6000,
			set: (ctx, val) => {
				ctx.data.edit['beacon'] = +val;
			},
			args: {
				type: 'enum',
				value: rate_values,
			}
		},

		'multicast': {
			help: 'Multicast rate in kbps (e.g. 24000 = 24 Mbps)',
			default: 24000,
			set: (ctx, val) => {
				ctx.data.edit['multicast'] = +val;
			},
			args: {
				type: 'enum',
				value: rate_values,
			}
		},
	}
};

let Bands = { };

function create_band(band, values) {
	let allow_dfs = (band == '5G' || band == '6G');
	let channel_mode = [];
	let default_mode = 'HT';

	for (let mode in values.modes || []) {
		let base_mode = replace(mode, /[0-9+]+$/, '');
		if (!(base_mode in channel_mode)) {
			push(channel_mode, base_mode);
			default_mode = base_mode;
		}
	}

	let channel_width = map(values.widths || [20], w => '' + w);
	let default_width = 20;
	for (let w in values.widths || [])
		if (w < 160)
			default_width = w;

	let max_tx_power = 0;
	for (let c in values.channels || [])
		if (c.max_power > max_tx_power)
			max_tx_power = c.max_power;

	return {
		band,
		channel_mode,
		default_mode,
		channel_width,
		default_width: '' + default_width,
		allow_dfs,
		channels: values.channels,
		max_tx_power,
	};
}

model.uconfig.bands = [];

uconfig.add_node('ucRates', editor.new(rates_editor));

function rates_select_create(band) {
	return function(ctx, argv) {
		return ctx.set(null, {
			edit: uconfig.lookup([ 'radios', band, 'rates' ]),
		});
	};
}

for (let phy in wiphy.phys) {
	for (let k, v in phy.bands) {
		Bands[k] = create_band(k, v);
		push(model.uconfig.bands, k);
		let band_node = editor.new(radio_editor);
		band_node.rates = {
			help: 'Configure beacon and multicast rates',
			select_node: 'ucRates',
			select: rates_select_create(k),
		};
		uconfig.add_node(k, band_node);
	}
}

model.uconfig.bands = sort(uniq(model.uconfig.bands));

const ucEdit = {
	radios: {
		help: 'Manage the wireless radios on the device',

		args: [
			{
				name: 'band',
				type: 'enum',
				value: () => keys(Bands),
				required: true,
			}
		],

		select_node: '2G',

		select: function(ctx, argv) {
			let band = argv[0];
			if (!band) {
				warn(`Error: No radio provided\n`);
	                        return;
			}
			ctx.node = model.node[band];

			let band_data = Bands[band];
			let remote_phys = model.uconfig.remote_wiphy;
			if (remote_phys) {
				for (let phy in remote_phys)
					if (phy.bands?.[band])
						band_data = create_band(band, phy.bands[band]);
			}

			return ctx.set(`radios ${band}`, {
				...band_data,
				edit : uconfig.lookup([ 'radios', band ]),
			});
		},
	},
};
uconfig.add_node('ucEdit', ucEdit);
