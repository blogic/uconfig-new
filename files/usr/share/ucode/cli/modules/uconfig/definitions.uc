'use strict';

import * as uconfig from 'cli.uconfig';
import * as editor from 'cli.object-editor';

const auth_editor = {
	change_cb: uconfig.changed,

	named_args: {
		host: {
			help: 'The URI of the authentication server',
			required: true,
			args: {
				type: 'host',
			}
		},

		port: {
			help: 'The network port of the authentication server',
			default: 1812,
			args: {
				type: 'int',
				min: 1024,
				max: 65535,
			}
		},

		secret: {
			help: 'The shared RADIUS authentication secret',
			default: 'secret',
			args: {
				type: 'string',
			}
		},
	}
};

const acct_editor = {
	change_cb: uconfig.changed,

	named_args: {
		host: {
			help: 'The URI of the accounting server',
			required: true,
			args: {
				type: 'host',
			}
		},

		port: {
			help: 'The network port of the accounting server',
			default: 1813,
			args: {
				type: 'int',
				min: 1024,
				max: 65535,
			}
		},

		secret: {
			help: 'The shared RADIUS accounting secret',
			default: 'secret',
			args: {
				type: 'string',
			}
		},

		interval: {
			help: 'The interim accounting update interval in seconds',
			default: 60,
			args: {
				type: 'int',
				min: 60,
				max: 600,
			}
		},
	}
};

const dynamic_authorization_editor = {
	change_cb: uconfig.changed,

	named_args: {
		host: {
			help: 'The IP of the DAE client',
			args: {
				type: 'ipv4',
			}
		},

		port: {
			help: 'The network port that the DAE client can connect on',
			args: {
				type: 'int',
				min: 1024,
				max: 65535,
			}
		},

		secret: {
			help: 'The shared DAE authentication secret',
			args: {
				type: 'string',
			}
		},
	}
};

const radius_editor = {
	change_cb: uconfig.changed,

	named_args: {
		'nas-identifier': {
			help: 'NAS-Identifier string for RADIUS messages',
			args: {
				type: 'string',
			}
		},

		'chargeable-user-id': {
			help: 'Enable support for Chargeable-User-Identity (RFC 4372)',
			default: false,
			args: {
				type: 'bool',
			}
		},
	},
};

uconfig.add_node('ucDefRadiusAuth', editor.new(auth_editor));
uconfig.add_node('ucDefRadiusAcct', editor.new(acct_editor));
uconfig.add_node('ucDefRadiusDae', editor.new(dynamic_authorization_editor));

const ucDefRadiusServer = {
	authentication: {
		help: 'Configure RADIUS authentication server',
		select_node: 'ucDefRadiusAuth',
		select: function(ctx, argv) {
			return ctx.set(null, {
				edit: uconfig.lookup([ 'definitions', 'radius-servers', ctx.data.name, 'authentication' ]),
			});
		}
	},

	accounting: {
		help: 'Configure RADIUS accounting server',
		select_node: 'ucDefRadiusAcct',
		select: function(ctx, argv) {
			return ctx.set(null, {
				edit: uconfig.lookup([ 'definitions', 'radius-servers', ctx.data.name, 'accounting' ]),
			});
		}
	},

	'dynamic-authorization': {
		help: 'Configure Dynamic Authorization Extensions (DAE)',
		select_node: 'ucDefRadiusDae',
		select: function(ctx, argv) {
			return ctx.set(null, {
				edit: uconfig.lookup([ 'definitions', 'radius-servers', ctx.data.name, 'dynamic-authorization' ]),
			});
		}
	},
};
editor.new(radius_editor, ucDefRadiusServer);
uconfig.add_node('ucDefRadiusServer', ucDefRadiusServer);

const definitions_editor = {
	change_cb: uconfig.changed,

	named_args: {
		'ipv4-network': {
			help: 'Define the IPv4 range that can be used by downstream interfaces',
			args: {
				type: 'cidr4',
			}
		},

		'ipv6-network': {
			help: 'Define the IPv6 range that can be used by downstream interfaces',
			args: {
				type: 'cidr6',
			}
		},

		'ntp-servers': {
			help: 'Define which NTP servers shall be used',
			multiple: true,
			args: {
				type: 'host',
			}
		},
	},
};

const edit_create_destroy = {
	change_cb: uconfig.changed,

	types: {
		radius: {
			node_name: 'ucDefRadiusServer',
			node: ucDefRadiusServer,
			object: 'radius-servers',
			add: (ctx, type, name) => { return {}; }
		},
	},
};

const ucDefinitions = { };
editor.new(definitions_editor, ucDefinitions);
editor.edit_create_destroy(edit_create_destroy, ucDefinitions);
uconfig.add_node('ucDefinitions', ucDefinitions);

const ucEdit = {
	definitions: {
		help: 'Manage global definitions on the device',
		select_node: 'ucDefinitions',
		select: function(ctx, argv) {
			return ctx.set(null, {
				edit: uconfig.lookup([ 'definitions' ]),
				object_edit: uconfig.lookup([ 'definitions' ]),
			});
		},
	},
};
uconfig.add_node('ucEdit', ucEdit);
