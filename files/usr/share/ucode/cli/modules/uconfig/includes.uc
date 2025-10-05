'use strict';

import * as uconfig from 'cli.uconfig';

function source_validate(spec) {
	let parts = split(spec, ':');
	if (length(parts) != 2)
		return false;
	return (parts[0] in ['ucoord', 'local']) && length(parts[1]) > 0;
}

const ucIncludes = {
	show: {
		help: 'Show current include sources',
		call: function(ctx, argv) {
			let includes = model.uconfig.current_cfg.includes;
			if (!includes || !length(keys(includes)))
				return ctx.ok('No includes configured');

			let data = {};
			for (let name, source in includes)
				data[name] = source;
			return ctx.table('Includes', data);
		}
	},

	set: {
		help: 'Add or update an include source',
		args: [
			{
				name: 'name',
				help: 'Include name',
				type: 'string',
				required: true,
			}
		],
		named_args: {
			source: {
				help: 'Source spec (ucoord:<name> or local:<name>)',
				required: true,
				args: { type: 'string' },
			},
		},
		call: function(ctx, argv, named) {
			let name = argv[0];
			let source = named.source;

			if (!source_validate(source))
				return ctx.invalid_argument(`Invalid source format: ${source} (expected ucoord:<name> or local:<name>)`);

			model.uconfig.current_cfg.includes ??= {};
			model.uconfig.current_cfg.includes[name] = source;
			uconfig.changed();

			return ctx.ok(`Set include '${name}' = ${source}`);
		}
	},

	unset: {
		help: 'Remove an include source',
		args: [
			{
				name: 'name',
				help: 'Include name',
				type: 'enum',
				value: function(ctx) {
					return keys(model.uconfig.current_cfg.includes ?? {});
				},
				required: true,
			}
		],
		call: function(ctx, argv) {
			let name = argv[0];
			let includes = model.uconfig.current_cfg.includes;
			if (!includes || !(name in includes))
				return ctx.invalid_argument(`Include '${name}' not found`);

			delete includes[name];
			if (!length(keys(includes)))
				delete model.uconfig.current_cfg.includes;
			uconfig.changed();

			return ctx.ok(`Removed include '${name}'`);
		}
	},
};
uconfig.add_node('ucIncludes', ucIncludes);

const ucEdit = {
	includes: {
		help: 'Manage configuration include sources',
		select_node: 'ucIncludes',
		select: function(ctx, argv) {
			model.uconfig.current_cfg.includes ??= {};
			return ctx.set(null, {});
		},
	},
};
uconfig.add_node('ucEdit', ucEdit);
