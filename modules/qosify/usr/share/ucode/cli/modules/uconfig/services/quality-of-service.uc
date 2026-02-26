'use strict';

import { readjson } from 'uconfig.files';
import * as uconfig from 'cli.uconfig';
import * as editor from 'cli.object-editor';

let qos_db = readjson('/usr/share/ucode/uconfig/qos.json');
let service_names = sort(keys(qos_db.services ?? {}));
unshift(service_names, 'all');

function bulk_get(ctx, param, obj, argv) {
	obj.bulk_detection ??= {};
	return obj.bulk_detection;
}

const qos_editor = {
	change_cb: uconfig.changed,

	named_args: {
		'bulk-dscp': {
			help: 'DSCP value assigned to bulk flows',
			attribute: 'dscp',
			get_object: bulk_get,
			default: 'CS0',
			args: {
				type: 'enum',
				value: [
					'CS0', 'CS1', 'CS2', 'CS3', 'CS4', 'CS5', 'CS6', 'CS7',
					'AF11', 'AF12', 'AF13', 'AF21', 'AF22', 'AF23',
					'AF31', 'AF32', 'AF33', 'AF41', 'AF42', 'AF43',
					'EF', 'VA', 'LE',
				],
			},
		},

		'bulk-pps': {
			help: 'PPS rate triggering bulk flow classification',
			attribute: 'packets_per_second',
			get_object: bulk_get,
			default: 0,
			args: {
				type: 'int',
				min: 0,
			},
		},

		services: {
			help: 'Predefined service classifiers from qos.json',
			multiple: true,
			args: {
				type: 'enum',
				value: service_names,
			},
		},
	},
};

uconfig.add_node('ucQoS', editor.new(qos_editor));

const ucServices = {
	'quality-of-service': {
		help: 'Configure traffic classification',
		select_node: 'ucQoS',
		select: function(ctx, argv) {
			return ctx.set(null, {
				edit: uconfig.lookup([ 'services', 'quality-of-service' ]),
			});
		},
	},
};
uconfig.add_node('ucServices', ucServices);

push(model.uconfig.services, 'quality-of-service');
