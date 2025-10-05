'use strict';

import * as fs from 'fs';
import { change_password } from 'auth';
import * as config from 'config';
import * as libubus from 'ubus';

const SETTINGS_FILE = '/etc/uconfig/webui/settings';
const ROUTER_TEMPLATE = '/etc/uconfig/webui/webui-router.json';
const AP_TEMPLATE = '/etc/uconfig/webui/webui-ap.json';

let ubus = libubus.connect();

function ipv4_to_u32(ip_string) {
	let parts = split(ip_string, '.');
	if (length(parts) != 4)
		return null;

	let a = int(parts[0]);
	let b = int(parts[1]);
	let c = int(parts[2]);
	let d = int(parts[3]);

	return (a << 24) | (b << 16) | (c << 8) | d;
}

function cidr_to_mask(prefix_len) {
	if (prefix_len < 0 || prefix_len > 32)
		return null;

	return 0xffffffff << (32 - prefix_len);
}

function subnets_overlap(subnet1, subnet2) {
	let parts1 = split(subnet1, '/');
	let parts2 = split(subnet2, '/');

	if (length(parts1) != 2 || length(parts2) != 2)
		return false;

	let ip1 = ipv4_to_u32(parts1[0]);
	let ip2 = ipv4_to_u32(parts2[0]);
	let mask1 = cidr_to_mask(int(parts1[1]));
	let mask2 = cidr_to_mask(int(parts2[1]));

	if (ip1 == null || ip2 == null || mask1 == null || mask2 == null)
		return false;

	let network1 = ip1 & mask1;
	let network2 = ip2 & mask2;

	return (network1 & mask2) == network2 || (network2 & mask1) == network1;
}

function radios_generate() {
	let available_radios = ubus.call('uconfig-ui', 'radios');
	if (!available_radios)
		return {};

	let radios = {};

	if (available_radios['2G']) {
		radios['2G'] = {
			'channel': 'auto',
			'channel-mode': 'HE',
			'channel-width': 20
		};
	}

	if (available_radios['5G']) {
		radios['5G'] = {
			'channel': 36,
			'channel-mode': 'HE',
			'channel-width': 80
		};
	}

	if (available_radios['6G']) {
		radios['6G'] = {
			'channel': 'auto',
			'channel-mode': 'EHT',
			'channel-width': 160
		};
	}

	return radios;
}

function settings_load() {
	let data = fs.readfile(SETTINGS_FILE);
	if (!data)
		return { configured: false };

	let settings = json(data);
	if (!settings)
		return { configured: false };

	return settings;
}

function settings_save(settings) {
	let data = sprintf('%.J\n', settings);
	let result = fs.writefile(SETTINGS_FILE, data);
	if (!result)
		return { error: 'Failed to write settings file' };

	return { success: true };
}

function config_generate(wizard_params) {
	let template_path = wizard_params.mode == 'router' ? ROUTER_TEMPLATE : AP_TEMPLATE;
	let template_data = fs.readfile(template_path);
	if (!template_data)
		return null;

	let cfg = json(template_data);
	if (!cfg)
		return null;

	cfg.uuid = time();
	cfg.unit.timezone = wizard_params.timezone;
	cfg.radios = radios_generate();

	let upstream_interface = wizard_params.mode == 'router' ? 'uplink' : 'main';
	let upstream = cfg.interfaces[upstream_interface];
	if (!upstream)
		return null;

	upstream.ipv4.addressing = wizard_params.uplink_addressing;
	if (wizard_params.uplink_addressing == 'static') {
		upstream.ipv4.subnet = wizard_params.uplink_subnet;
		upstream.ipv4.gateway = wizard_params.uplink_gateway;
		upstream.ipv4['use-dns'] = [ wizard_params.uplink_dns ];

		if (wizard_params.mode == 'router' && cfg.interfaces.main?.ipv4?.subnet) {
			if (subnets_overlap(cfg.interfaces.main.ipv4.subnet, wizard_params.uplink_subnet)) {
				cfg.interfaces.main.ipv4.subnet = '172.16.0.1/24';
			}
		}
	}

	if (cfg.interfaces.main?.ssids?.main) {
		cfg.interfaces.main.ssids.main.ssid = wizard_params.ssid;
		if (cfg.interfaces.main.ssids.main.template) {
			cfg.interfaces.main.ssids.main.template.key = wizard_params.wifi_password;
			cfg.interfaces.main.ssids.main.template.security = wizard_params.security;
		}
	}

	return cfg;
}

function wizard_apply(wizard_params) {
	if (type(wizard_params) != 'object')
		return { error: 'Invalid parameters' };

	let required = [ 'mode', 'password', 'timezone', 'ssid', 'wifi_password', 'security', 'uplink_addressing' ];
	for (let field in required) {
		if (!wizard_params[field])
			return { error: `Missing required field: ${field}` };
	}

	if (wizard_params.uplink_addressing == 'static') {
		let static_fields = [ 'uplink_subnet', 'uplink_gateway', 'uplink_dns' ];
		for (let field in static_fields) {
			if (!wizard_params[field])
				return { error: `Missing required field for static addressing: ${field}` };
		}
	}

	let password_result = change_password(wizard_params.password);
	if (password_result.error)
		return password_result;

	let generated_config = config_generate(wizard_params);
	if (!generated_config)
		return { error: 'Failed to generate configuration from template' };

	let store_result = config.store(generated_config);
	if (store_result.error) {
		config.cleanup();
		return store_result;
	}

	let validate_result = config.validate();
	if (!validate_result.success) {
		config.cleanup();
		return { error: validate_result.error, exit_code: validate_result.exit_code };
	}

	let apply_result = config.apply();
	config.cleanup();

	if (!apply_result.success)
		return { error: apply_result.error, exit_code: apply_result.exit_code };

	let settings_result = settings_save({ configured: true });
	if (settings_result.error)
		return settings_result;

	return { success: true };
}

export function is_configured() {
	let settings = settings_load();
	return settings.configured ?? true;
};

export function wizard_apply_wrapper(params) {
	return wizard_apply(params);
};
