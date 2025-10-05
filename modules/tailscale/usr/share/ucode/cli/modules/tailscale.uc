'use strict';

import { popen } from 'fs';
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
	return status?.BackendState;
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

function format_bytes(bytes) {
	if (!bytes)
		return '0 B';

	let units = ['B', 'KB', 'MB', 'GB', 'TB'];
	let i = 0;
	while (bytes >= 1024 && i < length(units) - 1) {
		bytes /= 1024;
		i++;
	}
	return sprintf('%.1f %s', bytes, units[i]);
}

function format_uptime(seconds) {
	if (!seconds)
		return 'unknown';

	let days = int(seconds / 86400);
	let hours = int((seconds % 86400) / 3600);
	let mins = int((seconds % 3600) / 60);

	if (days > 0)
		return sprintf('%dd %dh %dm', days, hours, mins);
	if (hours > 0)
		return sprintf('%dh %dm', hours, mins);
	return sprintf('%dm', mins);
}

const Root = {
	tailscale: {
		help: 'Tailscale VPN management',
		select_node: 'tailscale',
	},
};

const tailscale_node = {
	status: {
		help: 'Show Tailscale connection status',
		call: function(ctx, argv) {
			if (!tailscale_running())
				return ctx.error('ERROR', 'Tailscale service is not running');

			let cmd = popen('tailscale status --json', 'r');
			if (!cmd)
				return ctx.error('ERROR', 'Failed to execute tailscale status');

			let output = cmd.read('all');
			cmd.close();

			if (!output)
				return ctx.error('ERROR', 'No output from tailscale status');

			let status = json(output);
			if (!status)
				return ctx.error('ERROR', 'Failed to parse tailscale status');

			printf('Backend State: %s\n', status.BackendState);

			if (status.BackendState != 'Running')
				return ctx.ok();

			if (status.TailscaleIPs)
				printf('Tailscale IPs: %s\n', join(', ', status.TailscaleIPs));

			if (status.Self) {
				printf('Hostname:      %s\n', status.Self.HostName);
				printf('DNS Name:      %s\n', status.Self.DNSName);
				printf('Online:        %s\n', status.Self.Online ? 'yes' : 'no');

				let created_ts = parse_timestamp(status.Self.Created);
				if (created_ts) {
					let uptime = time() - created_ts;
					printf('Uptime:        %s\n', format_uptime(uptime));
				}

				printf('Traffic:       RX %s / TX %s\n',
					format_bytes(status.Self.RxBytes),
					format_bytes(status.Self.TxBytes));
			}

			if (status.Peer && length(keys(status.Peer)) > 0) {
				printf('\nPeers:\n');
				for (let nodekey, peer in status.Peer) {
					printf('  %s (%s)\n', peer.HostName, peer.Online ? 'online' : 'offline');
					if (peer.TailscaleIPs)
						printf('    IPs: %s\n', join(', ', peer.TailscaleIPs));
				}
			}

			return ctx.ok();
		}
	},

	login: {
		help: 'Initiate Tailscale authentication',
		call: function(ctx, argv) {
			if (!tailscale_running())
				return ctx.error('ERROR', 'Tailscale service is not running');

			let state = tailscale_backend_state();
			if (state == 'Running')
				return ctx.error('ERROR', 'Tailscale is already authenticated and running');

			let cmd = popen('tailscale up --timeout 5s --json', 'r');
			if (!cmd)
				return ctx.error('ERROR', 'Failed to execute tailscale up');

			let output = cmd.read('all');
			cmd.close();

			if (!output)
				return ctx.error('ERROR', 'No output from tailscale up');

			let json_start = index(output, '{');
			if (json_start < 0)
				return ctx.error('ERROR', 'No JSON in response');

			let result = json(substr(output, json_start));
			if (!result)
				return ctx.error('ERROR', 'Failed to parse response');

			if (result.AuthURL) {
				printf('Authentication required.\n\n');
				printf('Visit this URL to authenticate:\n%s\n', result.AuthURL);
			} else if (result.BackendState == 'Running') {
				printf('Tailscale is now connected.\n');
			}

			return ctx.ok();
		}
	},

	start: {
		help: 'Start the Tailscale tunnel',
		call: function(ctx, argv) {
			if (!tailscale_running())
				return ctx.error('ERROR', 'Tailscale service is not running');

			let state = tailscale_backend_state();
			if (state == 'Running')
				return ctx.error('ERROR', 'Tailscale tunnel is already running');

			system('tailscale up');
			printf('Tailscale tunnel started.\n');
			return ctx.ok();
		}
	},

	stop: {
		help: 'Stop the Tailscale tunnel',
		call: function(ctx, argv) {
			if (!tailscale_running())
				return ctx.error('ERROR', 'Tailscale service is not running');

			let state = tailscale_backend_state();
			if (state == 'Stopped')
				return ctx.error('ERROR', 'Tailscale tunnel is already stopped');

			system('tailscale down');
			printf('Tailscale tunnel stopped.\n');
			return ctx.ok();
		}
	},
};

model.add_nodes({ Root, tailscale: tailscale_node });
