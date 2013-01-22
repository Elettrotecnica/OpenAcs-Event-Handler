ad_library {
    Event handling procedures
    
    @author Antonio Pisano
}


namespace eval evnt {}


ad_proc -private evnt::obtain {
    -name:required
} {
    This proc creates a new event and saves its reference into the server variables.
    If the event specified with that name already exists, just returns the existing event.
    
    Returns a list containing the event and mutex handles.
} {
    # If all the variables for event and mutex exist into the server variables...
    if {[nsv_exists ::evnt_events ${name}::event] && [nsv_exists ::evnt_events ${name}::mutex]} {
	# ...just get them.
	set event_id [nsv_get ::evnt_events ${name}::event]
	set mutex_id [nsv_get ::evnt_events ${name}::mutex]
    } else {
	# ...else generate new event and mutex ids...
	set event_id [ns_event create]
	set mutex_id [ns_mutex create]
	# ...and save them.
	nsv_set ::evnt_events ${name}::event $event_id
	nsv_set ::evnt_events ${name}::mutex $mutex_id
    }

    return [list $event_id $mutex_id]
}

ad_proc -public evnt::throw {
    -name:required
} {
    This proc broadcasts the event specified. If it didn't exist, it is created.
} {
    set evnt [evnt::obtain -name $name]
    set event_id [lindex $evnt 0]
    set mutex_id [lindex $evnt 1]
    
    ns_mutex lock $mutex_id
    ns_cond broadcast $event_id
    ns_mutex unlock $mutex_id
}


#
### Queue procs
#

ad_proc -private evnt::create_handler {
    -queue_id:required
    -event:required
} {
    This proc creates a new job to handle the event specified.
} {
    set event_id [lindex $event 0]
    set mutex_id [lindex $event 1]
    ns_job queue $queue_id "
	ns_mutex lock $mutex_id
	ns_cond wait $event_id $mutex_id
	ns_mutex unlock $mutex_id
	
	set retval \[list $event_id $mutex_id\]"
}

ad_proc -public evnt::handle_events {
    {-spec ""}
    {-max_events_to_handle 10}
} {
    Handles the events specified, executing the script each time they are triggered.
    Script is upleveled, so it is executed in the environment of the caller.
} { 
    set n_events [llength $spec]
    
    # No events given.
    if {$n_events == 0} {
	return
    }
    
    
    # Get the queue_id...
    set queue_id ::evnt_queue|[ns_conn authuser]|[ns_conn url]|[ns_job genid]
	    
    # ...and create the queue.
    ns_job create $queue_id [expr $n_events + 1]
    
    
    # For each event specified...
    foreach sp $spec {
	set name [string trim [lindex $sp 0]]
	set code [string trim [lindex $sp 1]]
	
	# ...ignore bogus specifications...
	if {$name eq "" || $code eq ""} {
	    continue
	}
	
	# ...obtain a reference to the event...
	set event [evnt::obtain -name $name]
	
	# ...associate the event id with the code to 
	# be executed when such event fires...
	set event_id [lindex $event 0]
	set handlers($event_id) $code
	
	# ...and start the handler for the event.
	create_handler -queue_id $queue_id -event $event
    }
    
    # We can free some memory now.
    unset spec sp n_events name code
    
    
    # We handle just a limited number of events as a security measure:
    # we can't let users generate neverending requests.
    for {set i 1} {$i <= $max_events_to_handle} {incr i} {
	# Wait for any of the handlers to fire...
	ns_job waitany $queue_id

	# ...then loop through the handlers...
	foreach handler [ns_job joblist $queue_id] {
	    set state [lindex $handler 3]
	    # ...find the ones which are done...
	    if {$state == "done"} {
		set event [lindex $handler 5]
		
		set event_id [lindex $event 0]
		# We execute the code associated with this event in the environment of the caller.
		uplevel $handlers($event_id)
		
		# ...schedule again a handler for the event caught (only if it is not the last execution)...
		if {$i != $max_events_to_handle} {
		    evnt::create_handler -queue_id $queue_id -event $event
		}
		
		set job_id [lindex $handler 1]
		# ...then delete the died handler.
		ns_job cancel $queue_id $job_id
	    }
	}
    }
    
    # Delete the queue.
    ns_job delete $queue_id
}
