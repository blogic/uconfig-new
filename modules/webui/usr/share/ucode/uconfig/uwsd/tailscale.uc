'use strict';

import { popen } from 'fs';
import {
	ERROR_INVALID_PARAMS,
	ERROR_INTERNAL,
	response_success,
	response_error
} from 'jsonrpc';
import * as ubus from 'ubus';

function tailscale_running() {
	let services = ubus.call('service', 'list', { name: 'tailscale' });
	if (!services || !services.tailscale)
		return false;

	let instance = services.tailscale.instances?.instance1;
	return instance?.running ?? false;
}

function tailscale_backend_state() {
	let cmd = popen('tailscale status --json', 'r');
	if (!cmd)
		return null;

	let output = cmd.read('all');
	cmd.close();

	if (!output)
		return null;

	let status = json(output);
	if (!status)
		return null;

	return status.BackendState;
}

function parse_timestamp(ts_string) {
	if (!ts_string || ts_string == '0001-01-01T00:00:00Z')
		return null;

	let cmd = popen(`date -d '${ts_string}' +%s`, 'r');
	if (!cmd)
		return null;

	let output = cmd.read('all');
	cmd.close();

	return output ? int(output) : null;
}

function tailscale_status() {
	if (!tailscale_running())
		return { error: 'Tailscale service is not running' };

	let cmd = popen('tailscale status --json', 'r');
	if (!cmd)
		return { error: 'Failed to execute tailscale status' };

	let output = cmd.read('all');
	cmd.close();

	if (!output)
		return { error: 'No output from tailscale status' };

	let status = json(output);
	if (!status)
		return { error: 'Failed to parse tailscale status JSON' };

	if (status.BackendState != 'Running')
		return { BackendState: status.BackendState };

	let created_ts = parse_timestamp(status.Self?.Created);
	let current_ts = time();
	let uptime = created_ts ? (current_ts - created_ts) : null;

	let peers = [];
	if (status.Peer) {
		for (let nodekey, peer in status.Peer) {
			push(peers, {
				HostName: peer.HostName,
				DNSName: peer.DNSName,
				TailscaleIPs: peer.TailscaleIPs,
				Online: peer.Online,
				LastSeen: peer.LastSeen,
				RxBytes: peer.RxBytes,
				TxBytes: peer.TxBytes,
				OS: peer.OS
			});
		}
	}

	return {
		BackendState: status.BackendState,
		TailscaleIPs: status.TailscaleIPs,
		HostName: status.Self?.HostName,
		DNSName: status.Self?.DNSName,
		Online: status.Self?.Online,
		Uptime: uptime,
		RxBytes: status.Self?.RxBytes,
		TxBytes: status.Self?.TxBytes,
		Peers: peers
	};
}

function tailscale_login() {
	let cmd = popen('tailscale up --timeout 5s --json', 'r');
	if (!cmd)
		return { error: 'Failed to execute tailscale up' };

	let output = cmd.read('all');
	cmd.close();

	if (!output)
		return { error: 'No output from tailscale up' };

	let result = json(output);
	if (!result)
		return { error: 'Failed to parse tailscale up JSON' };

	return {
		AuthURL: result.AuthURL,
		QR: result.QR,
		BackendState: result.BackendState
	};
}

function tailscale_start() {
	let state = tailscale_backend_state();
	if (!state)
		return { error: 'Failed to get tailscale state' };

	if (state == 'Running')
		return { error: 'Tailscale is already running' };

	system('tailscale up');
	return { success: true };
}

function tailscale_stop() {
	let state = tailscale_backend_state();
	if (!state)
		return { error: 'Failed to get tailscale state' };

	if (state == 'Stopped')
		return { error: 'Tailscale is already stopped' };

	system('tailscale down');
	return { success: true };
}

export function handle(send_response, id, params) {
	if (type(params) != 'object' || !params.action)
		return send_response(response_error(id, ERROR_INVALID_PARAMS, 'Invalid params'));

	let result;

	if (params.action == 'status')
		result = tailscale_status();
	else if (params.action == 'login')
		result = tailscale_login();
	else if (params.action == 'start')
		result = tailscale_start();
	else if (params.action == 'stop')
		result = tailscale_stop();
	else
		return send_response(response_error(id, ERROR_INVALID_PARAMS, 'Invalid action'));

	if (result.error)
		return send_response(response_error(id, ERROR_INTERNAL, result.error));

	send_response(response_success(id, result));
};
