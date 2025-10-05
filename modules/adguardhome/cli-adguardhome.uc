import * as uconfig from 'cli.uconfig';
import * as editor from "cli.object-editor";

const adguard_editor = {
	change_cb: uconfig.changed,

	named_args: {
		port: {
			help: 'Network port',
			default: 3000,
			required: true,
			args: {
				type: 'int',
				min: 1,
				max: 65535,
			}
		},

		'dns-intercept': {
			help: 'Intercept all DNS traffic',
			default: false,
			args: {
				type: 'bool',
			}
		},

		'servers': {
			help: 'The upstream DNS servers that will be used',
			multiple: true,
			set: (ctx, val) => {
				ctx.data.edit['servers'] = [];
				for (let k in val)
					push(ctx.data.edit['servers'], k);
			},
			args: {
				type: 'string',
			}
		},

		'htpasswd': {
			help: 'The bcrypt htpasswd used by the adguard UI',
			args: {
				type: 'string',
			}
		},
	}
};
uconfig.add_node('ucAdGuardHome', editor.new(adguard_editor));

const ucServices = {
	adguardhome: {
		help: 'Edit the AdGuardHome servers settings',
		select_node: 'ucAdGuardHome',
		select: function(ctx, argv) {
			return ctx.set(null, { edit : uconfig.lookup([ 'services', 'adguardhome' ])});
		},
	},
};
uconfig.add_node('ucServices', ucServices);

push(model.uconfig.services, 'adguardhome');
