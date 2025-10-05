{%
	// Helper functions
	function has_nlbwmon_service() {
		return services.is_present("nlbwmon");
	}

	function has_upstream_interface() {
		for (let k, v in state.interfaces)
			if (v.role == 'upstream')
				return true;

		return false;
	}

	function has_downstream_interface() {
		for (let k, v in state.interfaces)
			if (v.role == 'downstream')
				return true;

		return false;
	}

	// Main logic
	if (!has_nlbwmon_service())
		return;

	let enable = has_upstream_interface() && has_downstream_interface();

	services.set_enabled('nlbwmon', enable);
%}
