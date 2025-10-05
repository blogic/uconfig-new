'use strict';

function built_in_config() {
	return {
		authentication: {
			host: '127.0.0.1',
			port: 1812,
			secret: 'secret'
		},
		accounting: {
			host: '127.0.0.1',
			port: 1813,
			secret: 'secret'
		}
	};
}

export function lookup(radius_server, definitions) {
	if (radius_server == 'local')
		return built_in_config();

	if (definitions?.radius_servers?.[radius_server])
		return definitions.radius_servers[radius_server];

	return null;
};
