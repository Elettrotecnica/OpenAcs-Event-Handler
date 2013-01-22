set max_rounds 100

set events {
    something-happened
    something-else-happened
}

for {set i 0} {$i < $max_rounds} {incr i} {
    # We keep throwing one event, then the other.
    set event_name [lindex $events [expr $i % 2]]
    
    ns_write "Must tell everybody that \"$event_name!\"\n"
    evnt::throw -name $event_name

    ns_sleep 5
}

 
