set max_rounds 100

for {set i 0} {$i < $max_rounds} {incr i} {
    ns_write "Must tell everybody that something has happened!\n"
    evnt::throw -name "something-happened"
    ns_sleep 5
}

 
