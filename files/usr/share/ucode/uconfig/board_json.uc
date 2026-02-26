'use strict';

import { readjson } from 'uconfig.files';

export let board = readjson('/etc/board.json');

let _network = {};
let _macs = {};

if (board?.network) {
	for (let k, v in board.network) {
		if (!board.network.wan && k == 'lan')
			k = 'wan';
		if (v.ports)
			_network[k] = v.ports;
		if (v.device)
			_network[k] = [v.device];
		if (v.ifname)
			_network[k] = split(replace(v.ifname, /^ */, ''), ' ');
		if (v.macaddr)
			_macs[k] = v.macaddr;
	}
}

export let network = _network;
export let macaddr = length(_macs) ? _macs : null;
export let label_macaddr = board?.system?.label_macaddr;
export let compatible = board?.model?.id;
export let model_name = board?.model?.name;
