'use strict';

import * as uconfig from 'cli.uconfig';
import * as editor from 'cli.object-editor';
import * as state from 'uconfig.state';
import * as board_json from 'uconfig.board_json';
import { basename, glob, stat } from 'fs';

if (!board_json.board)
	return;

function is_simple_array(arr) {
	for (let v in arr)
		if (type(v) == 'object' || type(v) == 'array')
			return false;
	return true;
}

function format_value(val, indent) {
	let t = type(val);
	let out = '';

	if (t == 'array') {
		if (is_simple_array(val))
			return sprintf('[ %s ]\n', join(', ', val));

		for (let i, v in val)
			out += sprintf('%s- %s', indent, format_value(v, indent + '\t'));
		return out;
	}

	if (t == 'object') {
		out = '\n';
		for (let k, v in val)
			out += sprintf('%s%s: %s', indent, k, format_value(v, indent + '\t'));
		return out;
	}

	return sprintf('%s\n', val);
}

function nested_table(ctx, name, cfg) {
	printf('%s:\n', name);
	let cfg_keys = keys(cfg);
	for (let k in cfg_keys)
		printf('\t%s: %s', k, format_value(cfg[k], '\t\t'));

	return ctx.ok();
}

model.uconfig ??= {};
uconfig.update_status();

function rollback_uuids() {
	let configs = glob('/etc/uconfig/configs/uconfig.cfg.*');
	let uuids = map(configs, (v) => split(basename(v), '.')[2]);

	return filter(uuids, (v) => v != model.uconfig.status.uuid);
}

const rollback_args = [
	{
		name: 'uuid',
		help: 'UUID of the configuration to roll back to',
		type: 'enum',
		value: rollback_uuids,
	}
];

const uConfig = {
	disable: {
		help: 'Disable uConfig based UCI generation',
		call: function(ctx, argv) {
			let status = model.uconfig.status;

			if (!status.active)
				return ctx.error('SERVICE_NOT_RUNNING', 'Service not running');

			uconfig.service('disable');
			uconfig.service('stop');

			uconfig.update_status();

			return ctx.ok('Disabling');
		},
	},

	edit: {
		help: 'Edit the active configuration',
		no_subcommands: true,
		select_node: 'ucEdit',
		select: function(ctx, argv) {
			if (!model.uconfig.current_cfg) {
				printf('FIXME: no config applied\n');
				return null;
			}

			return ctx.set(null, {
				object_edit: uconfig.lookup(),
			});
		},
	},

	enable: {
		help: 'Enable uConfig based UCI generation',
		call: function(ctx, argv) {
			let status = model.uconfig.status;

			if (status.active)
				return ctx.error('SERVICE_ALREADY_RUNNING', 'Service already running');
			else if (!status.uuid)
				return ctx.error('CONFIGURATION_NOT_AVAILABLE', 'Configuration not available');

			uconfig.service('enable');
			uconfig.service('start');

			uconfig.update_status();

			return ctx.ok('Enabling');
		},
	},

	list: {
		help: 'List all known configurations',
		call: function(ctx, argv) {
			let configs = glob('/etc/uconfig/configs/uconfig.cfg.*');
			configs = map(configs, (v) => split(basename(v), '.')[2]);
			configs = map(configs, function(v) {
				let t = localtime(+v);
				let ts = sprintf('%04d-%02d-%02d %02d:%02d:%02d',
					t.year, t.mon + 1, t.mday,
					t.hour, t.min, t.sec);
				let suffix = model.uconfig.status.uuid == v ? ' - active' : '';
				return v + ' - ' + ts + suffix;
			});

			return ctx.list('Configs', configs);
		}
	},

	rollback: {
		help: 'Roll back to a previous configuration',
		args: rollback_args,
		call: function(ctx, argv) {
			let uuid = shift(argv);

			if (!uuid)
				return ctx.error('MISSING_OPTION', 'Missing UUID');

			let path = `/etc/uconfig/configs/uconfig.cfg.${uuid}`;
			if (!stat(path))
				return ctx.error('CONFIG_NOT_FOUND', `Configuration ${uuid} not found`);

			if (system(`/usr/bin/uconfig-apply -ur ${path}`))
				return ctx.error('ROLLBACK_FAILED', 'Failed to roll back config');

			uconfig.update_status();

			return ctx.ok('Rolled back');
		}
	},

	show: {
		help: 'Print the raw active config',
		call: function(ctx) {
			if (!model.uconfig.current_cfg)
				return ctx.error('CONFIGURATION_NOT_AVAILABLE', 'Configuration not available');

			return nested_table(ctx, 'Config', model.uconfig.current_cfg);
		},
	},

	state: {
		help: 'Get the current state of the device',
		call: function(ctx, argv) {
			return nested_table(ctx, 'State', state.get());
		},
	},

	status: {
		help: 'Show current configuration status',
		call: function(ctx, argv) {
			let status = model.uconfig.status;

			if (!status.active || !status.uuid)
				return ctx.error('NOT_ACTIVE', 'uConfig is not active');

			let t = gmtime(status.uuid);
			let data = {
				uuid: status.uuid,
				created: sprintf('%02d:%02d:%02d %02d.%02d.%d', t.hour, t.min, t.sec, t.mday, t.mon, t.year),
			};

			return nested_table(ctx, 'Status', data);
		}
	},
};

model.add_node('uConfig', uConfig);

function exit_uconfig_cb() {
	if (!model.uconfig.changed)
		return true;

	let key = model.poll_key([ 'y', 'n' ], `Pending changes will be lost. Exit anyway ? (y|n) `);
	if (!key)
		key = 'y';

	warn(key + '\n');
	return key == 'y';
}

const Root = {
	uconfig: {
		help: 'uConfig based configuration',
		select_node: 'uConfig',
		select: function(ctx, argv) {
			ctx.add_hook('exit', exit_uconfig_cb);
			return ctx.set();
		},
	}
};
model.add_node('Root', Root);

model.add_modules('uconfig/*.uc');
