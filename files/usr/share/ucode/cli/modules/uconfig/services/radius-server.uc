'use strict';

import * as uconfig from 'cli.uconfig';
import * as editor from 'cli.object-editor';

function is_password_available(ctx, args, named) {
	let auth_type = named['auth-type'] || ctx.data.edit?.['auth-type'];
	return auth_type == 'password' || auth_type == 'both';
}

const user_editor = {
	change_cb: uconfig.changed,

	named_args: {
		'auth-type': {
			help: 'Authentication type',
			required: true,
			default: 'password',
			args: {
				type: 'enum',
				value: [ 'password', 'certificate', 'both' ],
			}
		},

		password: {
			help: 'User password (for password/both auth types)',
			available: is_password_available,
			args: {
				type: 'string',
				min: 1,
			}
		},

		'vlan-id': {
			help: 'Assign VLAN ID to user',
			args: {
				type: 'int',
				min: 1,
				max: 4094,
			}
		},

		'rate-limit-upload': {
			help: 'Upload rate limit in kbps',
			args: {
				type: 'int',
			}
		},

		'rate-limit-download': {
			help: 'Download rate limit in kbps',
			args: {
				type: 'int',
			}
		},
	}
};
const ucRadiusUser = uconfig.add_node('ucRadiusUser', editor.new(user_editor));

const user_edit_create_destroy = {
	change_cb: uconfig.changed,

	types: {
		user: {
			node_name: 'ucRadiusUser',
			node: ucRadiusUser,
			object: 'users',
		},
	},
};

const radius_server_editor = {
	change_cb: uconfig.changed,

	named_args: {
		'auth-port': {
			help: 'RADIUS authentication port',
			default: 1812,
			args: {
				type: 'int',
				min: 1024,
				max: 65535,
			}
		},

		'acct-port': {
			help: 'RADIUS accounting port',
			default: 1813,
			args: {
				type: 'int',
				min: 1024,
				max: 65535,
			}
		},

		secret: {
			help: 'Shared secret for RADIUS clients',
			default: 'secret',
			args: {
				type: 'string',
			}
		},
	}
};
const ucRadiusServer = {};
editor.new(radius_server_editor, ucRadiusServer);
editor.edit_create_destroy(user_edit_create_destroy, ucRadiusServer);
uconfig.add_node('ucRadiusServer', ucRadiusServer);

const ucServices = {
	'radius-server': {
		help: 'Configure built-in RADIUS server',
		select_node: 'ucRadiusServer',
		select: function(ctx, argv) {
			return ctx.set(null, {
				edit: uconfig.lookup([ 'services', 'radius-server' ]),
				object_edit: uconfig.lookup([ 'services', 'radius-server' ]),
			});
		},
	},
};
uconfig.add_node('ucServices', ucServices);

push(model.uconfig.services, 'radius-server');
