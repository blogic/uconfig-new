'use strict';

import {
	ERROR_METHOD_NOT_FOUND,
	ERROR_INVALID_PARAMS,
	ERROR_INTERNAL,
	response_success,
	response_error
} from 'uconfig.uwsd.jsonrpc';

import * as libubus from 'ubus';
import * as fs from 'fs';
import { cursor } from 'uci';

let ubus = libubus.connect();

function base_device_name_get(device_name) {
	return replace(device_name, /p?\d+$/, '');
};

function device_size_get(device_name) {
	let base_dev = base_device_name_get(device_name);

	try {
		let sectors_raw = fs.readfile(`/sys/block/${base_dev}/size`);
		if (!sectors_raw)
			return null;

		let block_size_raw = fs.readfile(`/sys/block/${base_dev}/queue/logical_block_size`);
		if (!block_size_raw)
			return null;

		let sectors = +trim(sectors_raw);
		let block_size = +trim(block_size_raw);

		return sectors * block_size;
	} catch(e) {
		return null;
	}
};

function device_model_get(device_name) {
	let base_dev = base_device_name_get(device_name);

	try {
		let model = fs.readfile(`/sys/block/${base_dev}/device/model`);
		return model ? trim(model) : null;
	} catch(e) {
		return null;
	}
};

function device_removable_get(device_name) {
	let base_dev = base_device_name_get(device_name);

	try {
		let removable = fs.readfile(`/sys/block/${base_dev}/removable`);
		return removable ? (trim(removable) == '1') : false;
	} catch(e) {
		return false;
	}
};

function size_human_format(bytes) {
	if (bytes == null)
		return 'Unknown';

	const units = ['B', 'KB', 'MB', 'GB', 'TB'];
	let size = bytes;
	let unit_idx = 0;

	while (size >= 1024 && unit_idx < length(units) - 1) {
		size /= 1024;
		unit_idx++;
	}

	if (unit_idx == 0)
		return sprintf('%d %s', size, units[unit_idx]);
	else
		return sprintf('%.1f %s', size, units[unit_idx]);
};

function uci_mount_find(device_name, uuid, label) {
	let uci = cursor();
	let found_section = null;

	uci.foreach('fstab', 'mount', function(section) {
		if (section.device == device_name ||
		    (uuid && section.uuid == uuid) ||
		    (label && section.label == label)) {
			found_section = section;
			return false;
		}
	});

	return found_section;
};

function uci_samba_share_find(share_name) {
	let uci = cursor();
	let found_section = null;

	uci.load('samba4');
	uci.foreach('samba4', 'sambashare', function(section) {
		if (section.name == share_name) {
			found_section = section;
			return false;
		}
	});

	return found_section;
};

function samba_share_set(share_name, mount_path) {
	let uci = cursor();
	uci.load('samba4');

	let existing = uci_samba_share_find(share_name);
	if (existing)
		return true;

	let section_id = uci.add('samba4', 'sambashare');
	if (!section_id)
		return false;

	uci.set('samba4', section_id, 'name', share_name);
	uci.set('samba4', section_id, 'path', mount_path);
	uci.set('samba4', section_id, 'guest_ok', 'yes');
	uci.set('samba4', section_id, 'guest_only', 'yes');
	uci.set('samba4', section_id, 'read_only', 'no');
	uci.set('samba4', section_id, 'create_mask', '0666');
	uci.set('samba4', section_id, 'dir_mask', '0777');
	uci.set('samba4', section_id, 'force_root', '1');
	uci.set('samba4', section_id, 'inherit_owner', 'yes');

	return uci.commit('samba4');
};

function samba_share_delete(share_name) {
	let uci = cursor();
	uci.load('samba4');

	let existing = uci_samba_share_find(share_name);
	if (!existing)
		return true;

	uci.delete('samba4', existing['.name']);
	return uci.commit('samba4');
};

function device_info_enrich(blockd_device) {
	let device_name = blockd_device.device;
	let size_bytes = device_size_get(device_name);

	let enriched = {
		name: device_name,
		device: `/dev/${device_name}`,
		type: blockd_device.type ?? 'unknown',
		uuid: blockd_device.uuid ?? null,
		label: blockd_device.label ?? null,
		version: blockd_device.version ?? null,
		size_bytes: size_bytes,
		size_human: size_human_format(size_bytes),
		mounted: blockd_device.mount ? true : false,
		mount_point: blockd_device.mount ?? null,
		model: device_model_get(device_name),
		removable: device_removable_get(device_name)
	};

	let uci_section = uci_mount_find(device_name, enriched.uuid, enriched.label);
	enriched.configured = uci_section ? true : false;
	enriched.config_target = uci_section ? uci_section.target : `/mnt/${device_name}`;
	enriched.config_enabled = uci_section ? (uci_section.enabled == '1') : false;

	return enriched;
};

function list() {
	let block_info = ubus.call('block', 'info', {});

	if (!block_info || !block_info.devices)
		return { error: 'Failed to retrieve block device information' };

	let devices = [];

	for (let dev in block_info.devices) {
		if (dev.type == 'ubifs' || dev.type == 'squashfs')
			continue;

		if (dev.mount && (dev.mount == '/rom' || dev.mount == '/overlay'))
			continue;

		push(devices, device_info_enrich(dev));
	}

	return { devices: devices };
};

function mount() {
	let result = system('block mount');

	if (result != 0)
		return { error: 'Failed to mount devices' };

	return { success: true };
};

function umount() {
	let result = system('block umount');

	if (result != 0)
		return { error: 'Failed to unmount devices' };

	return { success: true };
};

function toggle(device_name) {
	let block_info = ubus.call('block', 'info', { device: device_name });

	if (!block_info)
		return { error: 'Device not found' };

	let uuid = block_info.uuid;
	let label = block_info.label;

	if (!uuid && !label)
		return { error: 'Device has no UUID or label' };

	let share_name = label ?? device_name;
	let mount_path = `/mnt/${share_name}`;

	let uci = cursor();
	uci.load('fstab');

	let existing_section = uci_mount_find(device_name, uuid, label);
	let section_id;
	let new_enabled;

	if (existing_section) {
		section_id = existing_section['.name'];
		let current_enabled = existing_section.enabled ?? '0';
		new_enabled = (current_enabled == '1') ? '0' : '1';
		uci.set('fstab', section_id, 'enabled', new_enabled);
		uci.set('fstab', section_id, 'target', mount_path);
	} else {
		section_id = uci.add('fstab', 'mount');
		if (!section_id)
			return { error: 'Failed to create UCI mount section' };

		if (uuid)
			uci.set('fstab', section_id, 'uuid', uuid);
		else
			uci.set('fstab', section_id, 'label', label);

		uci.set('fstab', section_id, 'target', mount_path);
		uci.set('fstab', section_id, 'enabled', '1');
		new_enabled = '1';
	}

	if (!uci.commit('fstab'))
		return { error: 'Failed to commit UCI changes' };

	if (new_enabled == '1') {
		if (!samba_share_set(share_name, mount_path))
			return { error: 'Failed to create samba share' };
	} else {
		if (!samba_share_delete(share_name))
			return { error: 'Failed to delete samba share' };
	}

	system('/etc/init.d/samba4 restart');

	return { success: true };
};

export function handle(send_response, id, params) {
	if (type(params) != 'object' || !params.action)
		return send_response(response_error(id, ERROR_INVALID_PARAMS, 'Invalid params'));

	if (params.action == 'list') {
		let result = list();
		if (result.error)
			return send_response(response_error(id, ERROR_INTERNAL, result.error));
		return send_response(response_success(id, result));
	}

	if (params.action == 'mount') {
		let result = mount();
		if (result.error)
			return send_response(response_error(id, ERROR_INTERNAL, result.error));
		return send_response(response_success(id, result));
	}

	if (params.action == 'umount') {
		let result = umount();
		if (result.error)
			return send_response(response_error(id, ERROR_INTERNAL, result.error));
		return send_response(response_success(id, result));
	}

	if (params.action == 'toggle') {
		if (!params.device)
			return send_response(response_error(id, ERROR_INVALID_PARAMS, 'Missing device parameter'));

		let result = toggle(params.device);
		if (result.error)
			return send_response(response_error(id, ERROR_INTERNAL, result.error));
		return send_response(response_success(id, result));
	}

	return send_response(response_error(id, ERROR_INVALID_PARAMS, 'Invalid action'));
};
