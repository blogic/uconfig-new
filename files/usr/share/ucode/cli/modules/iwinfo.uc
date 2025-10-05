'use strict';

import * as iwinfo from 'iwinfo';

function nested_table(name, table) {
	printf('%s:\n', name);
	for (let k in keys(table))
		printf('    %-18s%s\n', k + ':', table[k]);
}

function device_list() {
	iwinfo.update();
	return keys(iwinfo.ifaces);
}

function format_info(dev) {
	let table = {
		'SSID': dev.ssid ?? '(not set)',
		'MAC': dev.mac,
		'Mode': dev.mode,
		'Channel': dev.channel,
		'Frequency': dev.freq + ' GHz',
		'HT Mode': dev.htmode ?? 'unknown',
		'Centre Frequency 1': dev.center_freq1,
		'Centre Frequency 2': dev.center_freq2,
		'TX Power': dev.txpower + ' dBm',
		'Noise': dev.noise + ' dBm',
		'Signal': dev.signal + ' dBm',
		'Quality': dev.quality + '/70',
		'Bit Rate': dev.bitrate + ' MBit/s',
		'Encryption': dev.encryption,
		'HW Mode': dev.hwmode,
		'PHY': dev.phy,
		'Hardware Type': dev.hw_type,
		'Hardware ID': dev.hw_id,
		'Power Offset': dev.power_offset,
		'Channel Offset': dev.channel_offset,
		'Supports VAPs': dev.vaps,
	};

	if (dev.owe_transition_ifname)
		table['OWE Transition'] = dev.owe_transition_ifname;

	return table;
}

const iwinfo_device = {
	info: {
		help: 'Show interface information',
		call: function(ctx, argv) {
			iwinfo.update();
			let list = iwinfo.info(ctx.data.device);

			if (!length(list))
				return ctx.error('NOT_FOUND', 'No wireless interface found');

			for (let dev in list)
				nested_table(dev.iface, format_info(dev));

			return ctx.ok();
		}
	},

	scan: {
		help: 'Scan for wireless networks',
		call: function(ctx, argv) {
			iwinfo.update();
			let results = iwinfo.scan(ctx.data.device);

			if (!length(results))
				return ctx.ok('No networks found');

			for (let cell in results) {
				let encryption = 'none';
				if (cell.crypto) {
					let mgmt = join('/', cell.crypto.key_mgmt);
					let pair = join('/', cell.crypto.pair);
					encryption = mgmt ? `${mgmt} (${pair})` : 'WEP';
				}

				let table = {
					'SSID': cell.ssid ?? '(hidden)',
					'Channel': cell.channel,
					'Frequency': cell.frequency + ' GHz',
					'Band': cell.band + ' GHz',
					'Signal': cell.dbm + ' dBm',
					'Quality': cell.quality + '/70',
					'Mode': cell.mode,
					'Encryption': encryption,
				};

				if (cell.country)
					table['Country'] = cell.country;

				if (cell.ht) {
					table['HT'] = sprintf('%s, %s, primary ch %d',
						cell.ht.chan_width,
						cell.ht.secondary_chan_off,
						cell.ht.primary_channel);
				}

				if (cell.vht) {
					table['VHT'] = sprintf('%s, centre ch %d/%d',
						cell.vht.chan_width,
						cell.vht.center_chan_1,
						cell.vht.center_chan_2);
				}

				if (cell.he) {
					table['HE'] = sprintf('%s, centre ch %d/%d',
						cell.he.chan_width,
						cell.he.center_chan_1,
						cell.he.center_chan_2);
				}

				if (cell.eht) {
					table['EHT'] = sprintf('%s, centre ch %d/%d',
						cell.eht.chan_width,
						cell.eht.center_chan_1,
						cell.eht.center_chan_2);
				}

				nested_table(cell.bssid, table);
			}

			return ctx.ok();
		}
	},

	txpowerlist: {
		help: 'Show available TX power levels',
		call: function(ctx, argv) {
			iwinfo.update();
			let list = iwinfo.txpowerlist(ctx.data.device);

			if (!length(list))
				return ctx.error('NOT_FOUND', 'No TX power information available');

			let rows = [];
			for (let level in list) {
				let marker = level.active ? '*' : '';
				push(rows, sprintf('%s%d dBm (%d mW)', marker, level.dbm, level.mw));
			}

			return ctx.list('TX Power Levels', rows);
		}
	},

	freqlist: {
		help: 'Show available frequencies and channels',
		call: function(ctx, argv) {
			iwinfo.update();
			let list = iwinfo.freqlist(ctx.data.device);

			if (!length(list))
				return ctx.error('NOT_FOUND', 'No frequency information available');

			let rows = [];
			for (let freq in list) {
				let marker = freq.active ? '* ' : '  ';
				let flags = length(freq.flags) ? ' [' + join(', ', freq.flags) + ']' : '';
				push(rows, sprintf('%sCh %3d (%s GHz, %s GHz band)%s',
					marker, freq.channel, freq.freq, freq.band, flags));
			}

			return ctx.list('Frequencies', rows);
		}
	},

	assoclist: {
		help: 'Show associated stations',
		call: function(ctx, argv) {
			iwinfo.update();
			let stations = iwinfo.assoclist(ctx.data.device);

			if (!length(keys(stations)))
				return ctx.ok('No associated stations');

			for (let mac, sta in stations) {
				let table = {
					'Signal': sta.signal + ' dBm',
					'Noise': sta.noise + ' dBm',
					'SNR': sta.snr + ' dB',
					'Inactive': sta.inactive_time + ' ms',
					'RX Bitrate': sta.rx.bitrate + ' MBit/s',
					'RX Packets': sta.rx.packets,
					'TX Bitrate': sta.tx.bitrate + ' MBit/s',
					'TX Packets': sta.tx.packets,
					'Expected Throughput': sta.expected_throughput + ' MBit/s',
				};

				if (length(sta.rx.flags))
					table['RX Flags'] = join(', ', sta.rx.flags);

				if (length(sta.tx.flags))
					table['TX Flags'] = join(', ', sta.tx.flags);

				nested_table(mac, table);
			}

			return ctx.ok();
		}
	},

	countrylist: {
		help: 'Show available regulatory countries',
		call: function(ctx, argv) {
			iwinfo.update();
			let data = iwinfo.countrylist(ctx.data.device);

			if (!data || !data.countries)
				return ctx.error('NOT_FOUND', 'No country information available');

			let rows = [];
			for (let code, name in data.countries) {
				let marker = (code == data.active) ? '* ' : '  ';
				push(rows, sprintf('%s%s - %s', marker, code, name));
			}

			return ctx.list('Countries', sort(rows));
		}
	},

	htmodelist: {
		help: 'Show supported HT modes',
		call: function(ctx, argv) {
			iwinfo.update();
			let list = iwinfo.htmodelist(ctx.data.device);

			if (!length(list))
				return ctx.error('NOT_FOUND', 'No HT mode information available');

			return ctx.list('HT Modes', list);
		}
	},
};

function device_entry(name) {
	return {
		help: 'Select interface ' + name,
		select_node: 'iwinfo_device',
		select: function(ctx, argv) {
			return ctx.set(name, { device: name });
		},
	};
}

function iwinfo_node_get() {
	iwinfo.update();
	let node = {
		info: {
			help: 'Show all interfaces information',
			call: function(ctx, argv) {
				iwinfo.update();
				let list = iwinfo.info();

				if (!length(list))
					return ctx.error('NOT_FOUND', 'No wireless interfaces found');

				for (let dev in list)
					nested_table(dev.iface, format_info(dev));

				return ctx.ok();
			}
		},

	};

	for (let dev in device_list())
		node[dev] = device_entry(dev);

	return node;
}

const Root = {
	iwinfo: {
		help: 'Wireless interface information',
		select_node: 'iwinfo',
	}
};

model.add_nodes({ Root, iwinfo: iwinfo_node_get(), iwinfo_device });
