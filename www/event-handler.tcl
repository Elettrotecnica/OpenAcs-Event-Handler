evnt::handle_events \
  -event_names {"something-happened"} \
  -script {
    ns_write "Hey! Looks like something has happened!\n"
}