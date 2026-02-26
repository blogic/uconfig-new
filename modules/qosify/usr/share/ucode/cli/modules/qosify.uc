'use strict';

import * as ubus from 'ubus';

function stats_table(entries) {
	let data = {};

	for (let name, stats in entries)
		if (stats.packets > 0)
			data[name] = sprintf('%d packets, %d bytes', stats.packets, stats.bytes);

	return data;
}

function qosify_show(ctx, argv) {
	let stats = ubus.call('qosify', 'get_stats');
	if (!stats)
		return ctx.error('UBUS_ERROR', 'qosify service not available');

	let classes = stats_table(stats.classes);
	let dscp = stats_table(stats.dscp);

	if (!length(keys(classes)) && !length(keys(dscp)))
		return ctx.ok('No traffic recorded');

	let result = {};

	if (length(keys(classes)))
		result.Classes = classes;
	if (length(keys(dscp)))
		result.DSCP = dscp;

	return ctx.multi_table('QoS Statistics', result);
}

const Root = {
	qosify: {
		help: 'Show QoS traffic statistics',
		call: qosify_show,
	},
};
model.add_node('Root', Root);
