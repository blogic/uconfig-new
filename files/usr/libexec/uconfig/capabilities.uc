#!/usr/bin/ucode

'use strict';

import * as fs from 'fs';
import { uci } from 'uconfig.uci';

let capa = {
	uuid: time(),
};

let board = fs.readfile('/etc/board.json');
board = json(board);

let config_file = 'initial.json';
if (fs.stat('/etc/init.d/uconfig-ui'))
	config_file = 'webui.json';

let initial = fs.readfile('/etc/uconfig/examples/' + config_file);
initial = json(initial);

initial.uuid = time();
initial.unit ??= {
	hostname: uci.get('system', '@system[-1]', 'hostname'),
};

capa.compatible = board.model.id;
capa.model = board.model.name;

capa.network = {};
let macs = {};
for (let k, v in board.network) {
	if (!board.network.wan && k == 'lan')
		k = 'wan';
	if (v.ports)
		capa.network[k] = v.ports;
	if (v.device)
		capa.network[k] = [v.device];
	if (v.ifname)
		capa.network[k] = split(replace(v.ifname, /^ */, ''), ' ');
	if (v.macaddr)
		macs[k] = v.macaddr;
}

if (length(macs))
	capa.macaddr = macs;

if (board.system?.label_macaddr)
	capa.label_macaddr = board.system.label_macaddr;

fs.writefile('/etc/uconfig/capabilities.json', capa);

let path = '/etc/uconfig/configs/uconfig.cfg.' + initial.uuid;
fs.writefile(path, initial);
fs.symlink(path, '/etc/uconfig/configs/uconfig.active');
