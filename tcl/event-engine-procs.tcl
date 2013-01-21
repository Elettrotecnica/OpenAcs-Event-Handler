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

ad_proc -private evnt::create_handlers {
    -queue_id:required
    -events:required
} {
    This proc creates a handler for every event specified.
} {
    foreach event $events {
	create_handler -queue_id $queue_id -event $event
    }
}


ad_proc -public evnt::handle_events {
    {-event_names ""}
    {-script ""}
    {-max_events_to_handle 10}
} {
    Handles the events specified, executing the script each time they are triggered.
    Script is upleveled, so it is executed in the environment of the caller.
} { 
    set n_events [llength $event_names]
    if {$n_events == 0} {
	# No jobs to schedule
	return
    }
    
    # Get the queue_id...
    set queue_id ::evnt_queue|[ns_conn authuser]|[ns_conn url]|[ns_job genid]
	    
    # Create the queue
    ns_job create $queue_id [expr $n_events + 1]
      
    # For each event name specified...
    foreach name $event_names {
	# ...we obtain a reference to the event...
	set evnt [evnt::obtain -name $name]
	# ...and add it to the events to handle.
	lappend events $evnt
    }
    
    # Now let's create the handlers!
    evnt::create_handlers -queue_id $queue_id -events $events
    
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
		# ...schedule again a handler for the event caught (only if it is not the last execution)...
		if {$i != $max_events_to_handle} {
		    set event [lindex $handler 5]
		    evnt::create_handler -queue_id $queue_id -event $event
		}
		
		set job_id [lindex $handler 1]
		# ...then delete the died handler.
		ns_job cancel $queue_id $job_id
	    }
	}
	
	# We execute the script in the environment of the caller
	uplevel $script
    }
    
    # Delete the queue.
    ns_job delete $queue_id
}
